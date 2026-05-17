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
    @Published var beforeScore: Int = 0
    @Published var showComparison = false
    
    func runFullDiagnostic(monitor: SystemMonitorManager) {
        isScanning = true
        isScanComplete = false
        results = []
        scanProgress = 0.0
        
        DispatchQueue.global(qos: .userInitiated).async {
            var items: [DiagnosticItem] = []
            var score = 100
            var step = 0.0
            let total = 12.0
            
            func next(_ s: String) {
                step += 1
                DispatchQueue.main.async { self.currentScanStep = s; self.scanProgress = step / total }
                Thread.sleep(forTimeInterval: 0.3)
            }
            
            // 1. RAM KHẢ DỤNG THỰC TẾ (Đo bằng os_proc_available_memory - chính xác nhất)
            next("Đo RAM khả dụng thực tế...")
            let availMB = Double(os_proc_available_memory()) / (1024*1024)
            let ram = monitor.getRAMUsage()
            let ramPercent = (ram.used / max(ram.total, 1)) * 100
            
            if availMB < 200 {
                items.append(DiagnosticItem(name: "RAM khả dụng CỰC THẤP", icon: "memorychip", status: .critical,
                    detail: String(format: "Chỉ còn %.0f MB RAM trống cho ứng dụng. Máy sẽ tự tắt app bất cứ lúc nào, gây mất dữ liệu và giật lag nghiêm trọng.", availMB),
                    canAutoFix: true, fixAction: "Ép iOS tắt app ngầm để giải phóng RAM"))
                score -= 25
            } else if availMB < 500 {
                items.append(DiagnosticItem(name: "RAM khả dụng thấp", icon: "memorychip", status: .warning,
                    detail: String(format: "Còn %.0f MB RAM trống (Đã dùng %.0f%%). App ngầm đang chiếm nhiều bộ nhớ.", availMB, ramPercent),
                    canAutoFix: true, fixAction: "Giải phóng RAM ngầm"))
                score -= 10
            } else {
                items.append(DiagnosticItem(name: "RAM dồi dào", icon: "memorychip", status: .good,
                    detail: String(format: "Còn %.0f MB RAM trống. Hệ thống hoạt động thoải mái.", availMB),
                    canAutoFix: false, fixAction: ""))
            }
            
            // 2. TỐC ĐỘ NÉN RAM (Đo RATE trong 2 giây - không dùng tổng tích lũy)
            next("Đo tốc độ nén RAM theo thời gian thực...")
            let compBefore = self.getCompressorCount()
            Thread.sleep(forTimeInterval: 2.0)
            let compAfter = self.getCompressorCount()
            let compRate = compAfter - compBefore // Số trang bị nén trong 2 giây
            
            if compRate > 5000 {
                items.append(DiagnosticItem(name: "CPU đang nén RAM liên tục", icon: "arrow.down.right.and.arrow.up.left", status: .critical,
                    detail: "Phát hiện \(compRate) trang RAM bị nén trong 2 giây vừa qua. CPU đang phải làm việc thêm để nén/giải nén bộ nhớ → Hao pin, nóng máy, giật khi chuyển app.",
                    canAutoFix: true, fixAction: "Ép giải phóng RAM để dừng chu kỳ nén"))
                score -= 20
            } else if compRate > 1000 {
                items.append(DiagnosticItem(name: "RAM đang bị nén nhẹ", icon: "arrow.down.right.and.arrow.up.left", status: .warning,
                    detail: "Phát hiện \(compRate) trang nén trong 2s. CPU đang phải nén bộ nhớ.",
                    canAutoFix: true, fixAction: "Giải phóng RAM"))
                score -= 8
            } else {
                items.append(DiagnosticItem(name: "Không có nén RAM bất thường", icon: "arrow.down.right.and.arrow.up.left", status: .good,
                    detail: "Tốc độ nén: \(compRate) trang/2s. CPU không bị quá tải nén bộ nhớ.",
                    canAutoFix: false, fixAction: ""))
            }
            
            // 3. CPU THỜI GIAN THỰC (Dùng hàm getCPUUsage có sẵn - đã đo delta)
            next("Đo tải CPU thời gian thực...")
            let cpu = monitor.getCPUUsage()
            
            if cpu > 80 {
                items.append(DiagnosticItem(name: "CPU quá tải", icon: "cpu", status: .critical,
                    detail: String(format: "CPU đang chạy %.0f%% ngay lúc này. Có tiến trình ngầm đang ngốn CPU → Hao pin, nóng máy.", cpu),
                    canAutoFix: true, fixAction: "Ép tắt tiến trình ngầm"))
                score -= 20
            } else if cpu > 50 {
                items.append(DiagnosticItem(name: "CPU hơi cao", icon: "cpu", status: .warning,
                    detail: String(format: "CPU %.0f%%. Mức trung bình.", cpu),
                    canAutoFix: false, fixAction: ""))
                score -= 5
            } else {
                items.append(DiagnosticItem(name: "CPU nhẹ nhàng", icon: "cpu", status: .good,
                    detail: String(format: "CPU %.0f%%.", cpu), canAutoFix: false, fixAction: ""))
            }
            
            // 4. THERMAL THROTTLING
            next("Kiểm tra bóp hiệu năng CPU...")
            let thermal = ProcessInfo.processInfo.thermalState
            if thermal == .critical || thermal == .serious {
                items.append(DiagnosticItem(name: "CPU bị Apple bóp hiệu năng", icon: "flame.fill",
                    status: thermal == .critical ? .critical : .warning,
                    detail: "Apple đã tự động giảm xung nhịp CPU để hạ nhiệt. Hiệu suất thực tế giảm 30-50%.",
                    canAutoFix: true, fixAction: "Dọn RAM để giảm tải → Hạ nhiệt CPU"))
                score -= (thermal == .critical ? 25 : 12)
            } else {
                items.append(DiagnosticItem(name: "CPU không bị bóp", icon: "thermometer.low", status: .good,
                    detail: "CPU đang chạy hiệu năng tối đa.", canAutoFix: false, fixAction: ""))
            }
            
            // 5. MẠNG
            next("Đo tốc độ phản hồi mạng...")
            let latency = self.measureLatency()
            if latency < 0 {
                items.append(DiagnosticItem(name: "Mạng bị lỗi", icon: "wifi.exclamationmark", status: .critical,
                    detail: "Không thể kết nối Internet. DNS lỗi hoặc mạng bị chặn.",
                    canAutoFix: true, fixAction: "Xoá DNS Cache + Cookie"))
                score -= 15
            } else if latency > 500 {
                items.append(DiagnosticItem(name: "Mạng chậm", icon: "wifi.exclamationmark", status: .warning,
                    detail: String(format: "Ping: %.0f ms. Gây giật video, game online lag.", latency),
                    canAutoFix: true, fixAction: "Xoá Cache mạng"))
                score -= 8
            } else {
                items.append(DiagnosticItem(name: "Mạng ổn định", icon: "wifi", status: .good,
                    detail: String(format: "Ping: %.0f ms.", latency), canAutoFix: false, fixAction: ""))
            }
            
            // 6. Ổ CỨNG
            next("Kiểm tra ổ cứng...")
            let disk = monitor.getDiskSpace()
            let freeGB = disk.total - disk.used
            if freeGB < 3 {
                items.append(DiagnosticItem(name: "Ổ cứng sắp đầy", icon: "internaldrive", status: .critical,
                    detail: String(format: "Chỉ còn %.1f GB trống!", freeGB),
                    canAutoFix: true, fixAction: "Xoá Cache + File tạm"))
                score -= 20
            } else {
                items.append(DiagnosticItem(name: "Ổ cứng thoải mái", icon: "internaldrive", status: .good,
                    detail: String(format: "Còn %.1f GB trống.", freeGB), canAutoFix: false, fixAction: ""))
            }
            
            // 7. UPTIME
            next("Kiểm tra thời gian hoạt động...")
            var bt = timeval()
            var btSz = MemoryLayout<timeval>.size
            var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
            sysctl(&mib, 2, &bt, &btSz, nil, 0)
            let days = (Date().timeIntervalSince1970 - Double(bt.tv_sec)) / 86400
            if days > 7 {
                items.append(DiagnosticItem(name: "Máy lâu chưa restart", icon: "arrow.clockwise",
                    status: days > 14 ? .critical : .warning,
                    detail: String(format: "Máy chạy %.0f ngày. Kernel cache phình to → Lỗi Bluetooth, WiFi tự ngắt, Face ID chậm.", days),
                    canAutoFix: false, fixAction: "Hãy khởi động lại máy"))
                score -= (days > 14 ? 15 : 8)
            } else {
                items.append(DiagnosticItem(name: "Uptime tốt", icon: "arrow.clockwise", status: .good,
                    detail: String(format: "Chạy %.1f ngày.", days), canAutoFix: false, fixAction: ""))
            }
            
            // 8. WIRED MEMORY (RAM bị Kernel khoá cứng)
            next("Kiểm tra Wired Memory (RAM khoá cứng)...")
            var vmStat2 = vm_statistics64()
            var vmC2 = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
            _ = withUnsafeMutablePointer(to: &vmStat2) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(vmC2)) {
                    host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &vmC2)
                }
            }
            var ps2: vm_size_t = 0
            host_page_size(mach_host_self(), &ps2)
            let wiredMB = Double(vmStat2.wire_count) * Double(ps2) / (1024*1024)
            let inactiveMB = Double(vmStat2.inactive_count) * Double(ps2) / (1024*1024)
            
            if wiredMB > Double(ram.total) * 0.4 {
                items.append(DiagnosticItem(name: "Wired Memory quá cao", icon: "lock.fill", status: .warning,
                    detail: String(format: "Kernel đang khoá cứng %.0f MB RAM (Wired). Đây là vùng nhớ mà iOS giữ cho hệ thống, không thể giải phóng. Khi vượt 40%% tổng RAM → các app bị ép đóng liên tục.", wiredMB),
                    canAutoFix: false, fixAction: "Restart máy để Kernel giải phóng Wired Memory"))
                score -= 8
            } else {
                items.append(DiagnosticItem(name: "Wired Memory bình thường", icon: "lock.fill", status: .good,
                    detail: String(format: "Kernel khoá %.0f MB RAM. Mức bình thường.", wiredMB),
                    canAutoFix: false, fixAction: ""))
            }
            
            // 9. INACTIVE MEMORY (RAM rỗi chưa thu hồi)
            next("Kiểm tra Inactive Memory...")
            if inactiveMB > 500 {
                items.append(DiagnosticItem(name: "RAM rỗi chưa thu hồi", icon: "moon.zzz", status: .warning,
                    detail: String(format: "%.0f MB RAM đang ở trạng thái Inactive (không dùng nhưng chưa xoá). Đây là dữ liệu cũ của app đã đóng, iOS giữ lại phòng khi cần.", inactiveMB),
                    canAutoFix: true, fixAction: "Ép Memory Pressure để iOS thu hồi Inactive Memory"))
                score -= 5
            } else {
                items.append(DiagnosticItem(name: "Inactive Memory ổn", icon: "moon.zzz", status: .good,
                    detail: String(format: "Inactive: %.0f MB. Bình thường.", inactiveMB),
                    canAutoFix: false, fixAction: ""))
            }
            
            // 10. DISK I/O SPEED (Tốc độ ghi ổ cứng - phát hiện SSD chậm)
            next("Đo tốc độ ghi ổ cứng (SSD)...")
            let ioSpeed = self.measureDiskSpeed()
            if ioSpeed < 50 && ioSpeed > 0 {
                items.append(DiagnosticItem(name: "SSD ghi CHẬM bất thường", icon: "externaldrive.badge.exclamationmark", status: .critical,
                    detail: String(format: "Tốc độ ghi: %.0f MB/s. Bình thường phải trên 100 MB/s. SSD chậm gây: App khởi động lâu, chụp ảnh bị đơ, cập nhật iOS thất bại.", ioSpeed),
                    canAutoFix: true, fixAction: "Xoá file tạm để giảm tải I/O"))
                score -= 15
            } else if ioSpeed < 100 && ioSpeed > 0 {
                items.append(DiagnosticItem(name: "SSD hơi chậm", icon: "externaldrive.badge.exclamationmark", status: .warning,
                    detail: String(format: "Tốc độ ghi: %.0f MB/s. Hơi chậm so với bình thường.", ioSpeed),
                    canAutoFix: true, fixAction: "Xoá Cache giảm tải ổ cứng"))
                score -= 5
            } else {
                items.append(DiagnosticItem(name: "SSD nhanh", icon: "externaldrive.fill", status: .good,
                    detail: String(format: "Tốc độ ghi: %.0f MB/s. Ổ cứng hoạt động tốt.", ioSpeed),
                    canAutoFix: false, fixAction: ""))
            }
            
            // 11. THREAD COUNT (Số luồng xử lý)
            next("Đếm số luồng đang chạy...")
            var threadList: thread_act_array_t?
            var threadCount: mach_msg_type_number_t = 0
            let tkr = task_threads(mach_task_self_, &threadList, &threadCount)
            if tkr == KERN_SUCCESS {
                if let tl = threadList {
                    vm_deallocate(mach_task_self_, vm_address_t(bitPattern: tl), vm_size_t(Int(threadCount) * MemoryLayout<thread_act_t>.size))
                }
            }
            
            if threadCount > 50 {
                items.append(DiagnosticItem(name: "Quá nhiều luồng xử lý", icon: "chart.bar.fill", status: .warning,
                    detail: "App đang chạy \(threadCount) threads. Quá nhiều luồng gây tranh chấp CPU và hao pin.",
                    canAutoFix: false, fixAction: "Restart app để reset threads"))
                score -= 5
            } else {
                items.append(DiagnosticItem(name: "Thread count tốt", icon: "chart.bar.fill", status: .good,
                    detail: "Đang chạy \(threadCount) threads. Bình thường.",
                    canAutoFix: false, fixAction: ""))
            }
            
            // 12. PIN
            next("Kiểm tra pin...")
            let bat = UIDevice.current.batteryLevel
            if bat >= 0 && bat < 0.1 {
                items.append(DiagnosticItem(name: "Pin cực thấp", icon: "battery.0percent", status: .critical,
                    detail: String(format: "Pin %.0f%%! Nguy cơ mất dữ liệu.", bat*100),
                    canAutoFix: false, fixAction: "Cắm sạc ngay"))
                score -= 10
            } else {
                items.append(DiagnosticItem(name: "Pin ổn", icon: "battery.75percent", status: .good,
                    detail: bat >= 0 ? String(format: "Pin %.0f%%.", bat*100) : "Đang sạc.",
                    canAutoFix: false, fixAction: ""))
            }
            
            DispatchQueue.main.async {
                self.scanProgress = 1.0
                self.currentScanStep = "Hoàn tất!"
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
        showComparison = false
        beforeScore = healthScore
        fixProgress = "Đang đo RAM trước khi sửa..."
        
        DispatchQueue.global(qos: .userInitiated).async {
            let ramBefore = Double(os_proc_available_memory()) / (1024*1024)
            
            let fixable = self.results.filter { $0.canAutoFix && $0.status != .good }
            let needsRAMFix = fixable.contains { $0.name.contains("RAM") || $0.name.contains("CPU") || $0.name.contains("nén") || $0.name.contains("bóp") }
            let needsNetFix = fixable.contains { $0.name.contains("Mạng") || $0.name.contains("mạng") }
            let needsDiskFix = fixable.contains { $0.name.contains("cứng") }
            
            if needsRAMFix {
                DispatchQueue.main.async { self.fixProgress = "Đang ép iOS tắt app ngầm (Memory Pressure)..." }
                self.forceMemoryPressure()
            }
            
            if needsNetFix {
                DispatchQueue.main.async { self.fixProgress = "Đang xoá DNS Cache + Cookie rác..." }
                self.clearNetworkCaches()
                Thread.sleep(forTimeInterval: 0.5)
            }
            
            if needsDiskFix {
                DispatchQueue.main.async { self.fixProgress = "Đang xoá file tạm + Cache..." }
                self.clearDiskCaches()
                Thread.sleep(forTimeInterval: 0.5)
            }
            
            let ramAfter = Double(os_proc_available_memory()) / (1024*1024)
            let freedMB = ramAfter - ramBefore
            
            DispatchQueue.main.async {
                if freedMB > 10 {
                    self.fixProgress = String(format: "Sửa xong! Giải phóng được %.0f MB RAM. Đang quét lại...", freedMB)
                } else {
                    self.fixProgress = "Sửa xong! Máy đã sạch, không có app ngầm rác. Đang quét lại..."
                }
                self.showComparison = true
                self.isFixingAll = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.runFullDiagnostic(monitor: monitor)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func getCompressorCount() -> Int64 {
        var vmStat = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        _ = withUnsafeMutablePointer(to: &vmStat) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        return Int64(vmStat.decompressions)
    }
    
    private func forceMemoryPressure() {
        // Chạy 2 vòng Memory Pressure để đảm bảo iOS dọn triệt để
        for pass in 1...2 {
            let chunk = 50 * 1024 * 1024
            var ptrs: [UnsafeMutableRawPointer] = []
            while true {
                if os_proc_available_memory() < 120 * 1024 * 1024 { break }
                let p = mmap(nil, chunk, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0)
                if p != MAP_FAILED, let v = p { memset(v, 0, chunk); ptrs.append(v) } else { break }
                Thread.sleep(forTimeInterval: 0.01)
            }
            Thread.sleep(forTimeInterval: 2.0)
            for p in ptrs { munmap(p, chunk) }
            if pass < 2 { Thread.sleep(forTimeInterval: 1.0) }
        }
        Thread.sleep(forTimeInterval: 1.0)
    }
    
    private func measureDiskSpeed() -> Double {
        let tmpPath = (NSTemporaryDirectory() as NSString).appendingPathComponent("speed_test.tmp")
        let size = 10 * 1024 * 1024 // 10MB
        let data = Data(count: size)
        let start = Date()
        do {
            try data.write(to: URL(fileURLWithPath: tmpPath))
            let elapsed = Date().timeIntervalSince(start)
            try? FileManager.default.removeItem(atPath: tmpPath)
            if elapsed > 0 {
                return Double(size) / (1024 * 1024) / elapsed // MB/s
            }
        } catch {}
        return 0
    }
    
    private func clearNetworkCaches() {
        URLCache.shared.removeAllCachedResponses()
        if let cookies = HTTPCookieStorage.shared.cookies {
            for c in cookies { HTTPCookieStorage.shared.deleteCookie(c) }
        }
    }
    
    private func clearDiskCaches() {
        let tmpDir = NSTemporaryDirectory()
        if let files = try? FileManager.default.contentsOfDirectory(atPath: tmpDir) {
            for f in files { try? FileManager.default.removeItem(atPath: (tmpDir as NSString).appendingPathComponent(f)) }
        }
        if let cachePath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first,
           let files = try? FileManager.default.contentsOfDirectory(atPath: cachePath) {
            for f in files { try? FileManager.default.removeItem(atPath: (cachePath as NSString).appendingPathComponent(f)) }
        }
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
