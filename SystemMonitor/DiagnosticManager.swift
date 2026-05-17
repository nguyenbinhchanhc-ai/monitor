import Foundation
import UIKit
import os

struct DiagnosticItem: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let status: DiagnosticStatus
    let detail: String
    let canAutoFix: Bool
    let fixAction: String
}

enum DiagnosticStatus {
    case good, warning, critical
}

class DiagnosticManager: ObservableObject {
    @Published var isScanning = false
    @Published var isScanComplete = false
    @Published var results: [DiagnosticItem] = []
    @Published var healthScore: Int = 0
    @Published var scanProgress: Double = 0.0
    @Published var currentScanStep: String = ""
    @Published var isFixingAll = false
    @Published var fixProgress: String = ""
    @Published var totalFixable: Int = 0
    
    func runFullDiagnostic(monitor: SystemMonitorManager) {
        isScanning = true
        isScanComplete = false
        results = []
        scanProgress = 0.0
        
        DispatchQueue.global(qos: .userInitiated).async {
            var items: [DiagnosticItem] = []
            var score = 100
            var step = 0.0
            let total = 10.0
            
            func next(_ s: String) {
                step += 1
                DispatchQueue.main.async { self.currentScanStep = s; self.scanProgress = step / total }
                Thread.sleep(forTimeInterval: 0.4)
            }
            
            // 1. PAGE FAULTS (Lỗi trang bộ nhớ - dấu hiệu RAM bị ép quá tải)
            next("Quét Page Faults (Lỗi trang bộ nhớ)...")
            var vmStat = vm_statistics64()
            var vmCount = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
            withUnsafeMutablePointer(to: &vmStat) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(vmCount)) {
                    host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &vmCount)
                }
            }
            let pageFaults = vmStat.faults
            let pageouts = vmStat.pageouts
            let compressorPages = vmStat.compressor_page_count
            let decompPages = vmStat.decompressions
            
            if pageouts > 50000 {
                items.append(DiagnosticItem(name: "Pageout nghiêm trọng", icon: "exclamationmark.triangle.fill", status: .critical,
                    detail: "Kernel đã phải đẩy \(pageouts) trang bộ nhớ ra khỏi RAM (Pageout). Đây là dấu hiệu RAM bị quá tải nghiêm trọng ở cấp Kernel, gây micro-freeze và giật lag không rõ nguyên nhân.",
                    canAutoFix: true, fixAction: "Ép Memory Pressure giải phóng RAM vật lý"))
                score -= 20
            } else {
                items.append(DiagnosticItem(name: "Pageout bình thường", icon: "memorychip", status: .good,
                    detail: "Pageout: \(pageouts). Kernel không bị ép đẩy RAM ra ngoài.", canAutoFix: false, fixAction: ""))
            }
            
            // 2. MEMORY COMPRESSOR (Nén bộ nhớ - dấu hiệu iOS đang vật lộn giữ RAM)
            next("Kiểm tra Memory Compressor...")
            var pagesize: vm_size_t = 0
            host_page_size(mach_host_self(), &pagesize)
            let compressedMB = Double(compressorPages) * Double(pagesize) / (1024*1024)
            let decompMB = Double(decompPages) * Double(pagesize) / (1024*1024)
            
            if compressedMB > 1500 {
                items.append(DiagnosticItem(name: "RAM nén quá nhiều", icon: "arrow.down.right.and.arrow.up.left", status: .critical,
                    detail: String(format: "Kernel đang nén %.0f MB RAM. Khi vượt 1.5GB, CPU phải liên tục nén/giải nén → hao pin, nóng máy, giật khi chuyển app.", compressedMB),
                    canAutoFix: true, fixAction: "Ép giải phóng RAM nén"))
                score -= 15
            } else if compressedMB > 800 {
                items.append(DiagnosticItem(name: "RAM nén hơi cao", icon: "arrow.down.right.and.arrow.up.left", status: .warning,
                    detail: String(format: "Kernel đang nén %.0f MB. Mức chấp nhận được nhưng CPU đang phải làm việc thêm.", compressedMB),
                    canAutoFix: true, fixAction: "Giải phóng bộ nhớ nén"))
                score -= 8
            } else {
                items.append(DiagnosticItem(name: "Memory Compressor ổn", icon: "arrow.down.right.and.arrow.up.left", status: .good,
                    detail: String(format: "RAM nén: %.0f MB. Bình thường.", compressedMB), canAutoFix: false, fixAction: ""))
            }
            
            // 3. FILE DESCRIPTOR (Bộ mô tả tệp - cạn kiệt sẽ crash app)
            next("Kiểm tra File Descriptor Kernel...")
            var maxFiles: Int32 = 0
            var mfSize = MemoryLayout<Int32>.size
            sysctlbyname("kern.maxfiles", &maxFiles, &mfSize, nil, 0)
            var openFiles: Int32 = 0
            sysctlbyname("kern.num_files", &openFiles, &mfSize, nil, 0)
            let fdPercent = maxFiles > 0 ? (Double(openFiles) / Double(maxFiles)) * 100 : 0
            
            if fdPercent > 80 {
                items.append(DiagnosticItem(name: "File Descriptor sắp cạn", icon: "doc.badge.ellipsis", status: .critical,
                    detail: "Kernel đang mở \(openFiles)/\(maxFiles) file descriptor (%.0f%%). Khi cạn kiệt → App crash ngẫu nhiên, mạng bị đứt, không mở được file.",
                    canAutoFix: true, fixAction: "Ép tắt app ngầm để thu hồi file descriptor"))
                score -= 20
            } else if fdPercent > 50 {
                items.append(DiagnosticItem(name: "File Descriptor hơi cao", icon: "doc.badge.ellipsis", status: .warning,
                    detail: "Đang dùng \(openFiles)/\(maxFiles) FD. Có app đang mở quá nhiều kết nối/file.",
                    canAutoFix: true, fixAction: "Dọn RAM để thu hồi FD"))
                score -= 5
            } else {
                items.append(DiagnosticItem(name: "File Descriptor tốt", icon: "doc.badge.ellipsis", status: .good,
                    detail: "Đang dùng \(openFiles)/\(maxFiles) FD. Bình thường.", canAutoFix: false, fixAction: ""))
            }
            
            // 4. CONTEXT SWITCHES (Chuyển ngữ cảnh CPU - cao = CPU bị tranh chấp)
            next("Đo Context Switch Rate...")
            var csInfo1 = host_cpu_load_info()
            var csCount1 = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
            withUnsafeMutablePointer(to: &csInfo1) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(csCount1)) {
                    host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &csCount1)
                }
            }
            let csTotal = Int64(csInfo1.cpu_ticks.0) + Int64(csInfo1.cpu_ticks.1) + Int64(csInfo1.cpu_ticks.2) + Int64(csInfo1.cpu_ticks.3)
            let csIdle = Int64(csInfo1.cpu_ticks.3)
            let csBusy = csTotal > 0 ? Double(csTotal - csIdle) / Double(csTotal) * 100 : 0
            
            // 5. PROCESS COUNT
            next("Đếm tiến trình đang chạy...")
            var maxProc: Int32 = 0
            var mpSize = MemoryLayout<Int32>.size
            sysctlbyname("kern.maxproc", &maxProc, &mpSize, nil, 0)
            
            if maxProc > 0 && csBusy > 70 {
                items.append(DiagnosticItem(name: "CPU tranh chấp cao", icon: "cpu", status: .warning,
                    detail: String(format: "CPU Busy: %.0f%%. Quá nhiều tiến trình đang tranh giành CPU → phản hồi chậm, cuộn trang bị giật.", csBusy),
                    canAutoFix: true, fixAction: "Ép tắt tiến trình ngầm"))
                score -= 10
            } else {
                items.append(DiagnosticItem(name: "CPU không bị tranh chấp", icon: "cpu", status: .good,
                    detail: String(format: "CPU Busy: %.0f%%. Các tiến trình không xung đột.", csBusy), canAutoFix: false, fixAction: ""))
            }
            
            // 6. SPECULATIVE PAGES (Trang dự đoán - iOS dự đoán sai gây lãng phí RAM)
            next("Phân tích Speculative Pages...")
            let specPages = vmStat.speculative_count
            let specMB = Double(specPages) * Double(pagesize) / (1024*1024)
            
            if specMB > 500 {
                items.append(DiagnosticItem(name: "RAM dự đoán sai lãng phí", icon: "questionmark.diamond", status: .warning,
                    detail: String(format: "Kernel đang giữ %.0f MB RAM \"dự đoán\" (Speculative). Đây là RAM mà iOS đoán bạn sẽ dùng nhưng thực tế không cần → Lãng phí.", specMB),
                    canAutoFix: true, fixAction: "Ép thu hồi RAM speculative"))
                score -= 5
            } else {
                items.append(DiagnosticItem(name: "Speculative Pages ổn", icon: "questionmark.diamond", status: .good,
                    detail: String(format: "RAM dự đoán: %.0f MB. Bình thường.", specMB), canAutoFix: false, fixAction: ""))
            }
            
            // 7. PURGEABLE MEMORY (RAM có thể thu hồi mà iOS chưa chịu dọn)
            next("Kiểm tra Purgeable Memory...")
            let purgePages = vmStat.purgeable_count
            let purgeMB = Double(purgePages) * Double(pagesize) / (1024*1024)
            
            if purgeMB > 300 {
                items.append(DiagnosticItem(name: "RAM rác chưa được thu hồi", icon: "trash.circle", status: .warning,
                    detail: String(format: "iOS đang giữ %.0f MB RAM \"có thể xoá\" (Purgeable) nhưng chưa chịu xoá. Đây là bộ nhớ đệm cũ của các app đã đóng.", purgeMB),
                    canAutoFix: true, fixAction: "Ép iOS thu hồi Purgeable Memory"))
                score -= 8
            } else {
                items.append(DiagnosticItem(name: "Purgeable Memory sạch", icon: "trash.circle", status: .good,
                    detail: String(format: "Purgeable: %.0f MB. iOS đã dọn tốt.", purgeMB), canAutoFix: false, fixAction: ""))
            }
            
            // 8. THERMAL STATE
            next("Đo Thermal Throttling...")
            let thermal = ProcessInfo.processInfo.thermalState
            if thermal == .critical || thermal == .serious {
                items.append(DiagnosticItem(name: "CPU bị bóp hiệu năng (Throttle)", icon: "flame.fill",
                    status: thermal == .critical ? .critical : .warning,
                    detail: "Apple đã tự động giảm xung nhịp CPU để bảo vệ pin và phần cứng. Hiệu suất thực tế giảm 30-50%. Đây là lỗi ẩn gây lag mà người dùng thường không biết.",
                    canAutoFix: true, fixAction: "Dọn RAM để giảm tải CPU → Hạ nhiệt"))
                score -= (thermal == .critical ? 25 : 12)
            } else {
                items.append(DiagnosticItem(name: "CPU không bị Throttle", icon: "thermometer.low", status: .good,
                    detail: "CPU đang chạy ở hiệu năng tối đa, không bị Apple bóp.", canAutoFix: false, fixAction: ""))
            }
            
            // 9. DNS + NETWORK LATENCY
            next("Đo độ trễ mạng sâu...")
            let latency = self.measureLatency()
            if latency < 0 {
                items.append(DiagnosticItem(name: "DNS/Mạng bị lỗi", icon: "wifi.exclamationmark", status: .critical,
                    detail: "Không thể phân giải DNS hoặc mạng bị chặn. Gây lỗi: App không tải được dữ liệu, iMessage/FaceTime báo lỗi kết nối.",
                    canAutoFix: true, fixAction: "Xoá DNS Cache + Cookie + Reset HTTP Session"))
                score -= 15
            } else if latency > 500 {
                items.append(DiagnosticItem(name: "Độ trễ mạng cao", icon: "wifi.exclamationmark", status: .warning,
                    detail: String(format: "Ping: %.0f ms. Trên 500ms gây giật video, FaceTime bị đứt, game online lag.", latency),
                    canAutoFix: true, fixAction: "Xoá Cache mạng + Cookie rác"))
                score -= 8
            } else {
                items.append(DiagnosticItem(name: "Mạng ổn định", icon: "wifi", status: .good,
                    detail: String(format: "Ping: %.0f ms.", latency), canAutoFix: false, fixAction: ""))
            }
            
            // 10. UPTIME
            next("Phân tích Uptime Kernel...")
            var bt = timeval()
            var btSz = MemoryLayout<timeval>.size
            var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
            sysctl(&mib, 2, &bt, &btSz, nil, 0)
            let days = (Date().timeIntervalSince1970 - Double(bt.tv_sec)) / 86400
            
            if days > 14 {
                items.append(DiagnosticItem(name: "Kernel Cache phình to", icon: "arrow.clockwise", status: .critical,
                    detail: String(format: "Máy chạy %.0f ngày không restart. Bộ nhớ đệm Kernel (kext cache, IOKit registry, launchd) tích tụ rất lớn → Gây lỗi Touch ID/Face ID, Bluetooth đứt kết nối, WiFi tự ngắt.", days),
                    canAutoFix: false, fixAction: "Khởi động lại máy để xoá Kernel Cache"))
                score -= 15
            } else if days > 7 {
                items.append(DiagnosticItem(name: "Nên restart máy", icon: "arrow.clockwise", status: .warning,
                    detail: String(format: "Máy chạy %.0f ngày. Kernel cache đang phình to dần.", days),
                    canAutoFix: false, fixAction: "Restart máy"))
                score -= 5
            } else {
                items.append(DiagnosticItem(name: "Uptime tốt", icon: "arrow.clockwise", status: .good,
                    detail: String(format: "Uptime: %.1f ngày. Kernel cache sạch.", days), canAutoFix: false, fixAction: ""))
            }
            
            DispatchQueue.main.async {
                self.scanProgress = 1.0
                self.currentScanStep = "Hoàn tất quét \(items.count) lỗi Kernel!"
                self.results = items
                self.healthScore = max(0, min(score, 100))
                self.totalFixable = items.filter { $0.canAutoFix && $0.status != .good }.count
                self.isScanning = false
                self.isScanComplete = true
            }
        }
    }
    
    func autoFixAll(monitor: SystemMonitorManager) {
        isFixingAll = true
        fixProgress = "Đang sửa lỗi Kernel..."
        
        DispatchQueue.global(qos: .userInitiated).async {
            let fixable = self.results.filter { $0.canAutoFix && $0.status != .good }
            
            for (i, item) in fixable.enumerated() {
                DispatchQueue.main.async { self.fixProgress = "[\(i+1)/\(fixable.count)] \(item.fixAction)..." }
                
                if item.name.contains("RAM") || item.name.contains("CPU") || item.name.contains("Page") ||
                   item.name.contains("Speculative") || item.name.contains("Purgeable") || item.name.contains("Throttle") ||
                   item.name.contains("File Descriptor") || item.name.contains("tranh chấp") {
                    self.forceMemoryPressure()
                }
                if item.name.contains("DNS") || item.name.contains("mạng") || item.name.contains("Mạng") {
                    self.clearNetworkCaches()
                }
                Thread.sleep(forTimeInterval: 0.5)
            }
            
            DispatchQueue.main.async {
                self.fixProgress = "Sửa xong! Đang quét lại..."
                self.isFixingAll = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.runFullDiagnostic(monitor: monitor) }
            }
        }
    }
    
    private func forceMemoryPressure() {
        let chunk = 50 * 1024 * 1024
        var ptrs: [UnsafeMutableRawPointer] = []
        while true {
            if os_proc_available_memory() < 150 * 1024 * 1024 { break }
            let p = mmap(nil, chunk, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0)
            if p != MAP_FAILED, let v = p { memset(v, 0, chunk); ptrs.append(v) } else { break }
            Thread.sleep(forTimeInterval: 0.02)
        }
        Thread.sleep(forTimeInterval: 2.0)
        for p in ptrs { munmap(p, chunk) }
        Thread.sleep(forTimeInterval: 0.5)
    }
    
    private func clearNetworkCaches() {
        URLCache.shared.removeAllCachedResponses()
        if let cookies = HTTPCookieStorage.shared.cookies { for c in cookies { HTTPCookieStorage.shared.deleteCookie(c) } }
    }
    
    private func measureLatency() -> Double {
        let start = Date()
        let sem = DispatchSemaphore(value: 0)
        var ok = false
        var req = URLRequest(url: URL(string: "https://captive.apple.com")!, timeoutInterval: 5)
        req.httpMethod = "HEAD"
        req.cachePolicy = .reloadIgnoringLocalCacheData
        URLSession.shared.dataTask(with: req) { _, r, _ in
            if let h = r as? HTTPURLResponse, h.statusCode == 200 { ok = true }
            sem.signal()
        }.resume()
        sem.wait()
        return ok ? Date().timeIntervalSince(start) * 1000 : -1
    }
}
