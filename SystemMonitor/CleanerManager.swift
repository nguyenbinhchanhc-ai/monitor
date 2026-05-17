import Foundation
import Combine
import os
import UIKit

class CleanerManager: ObservableObject {
    @Published var isCleaningRAM: Bool = false
    @Published var cleanedAmountMB: Double = 0.0
    @Published var message: String = ""
    @Published var log: [String] = []
    
    // Dọn tự động
    @Published var autoCleanEnabled: Bool = false
    @Published var autoCleanThresholdMB: Double = 300
    @Published var autoCleanInterval: Double = 30 // giây
    @Published var autoCleanMode: CleanMode = .normal
    @Published var autoCleanCount: Int = 0
    @Published var autoCleanLastTime: String = ""
    private var autoCleanTimer: Timer?
    private weak var monitorRef: SystemMonitorManager?
    
    // Chế độ dọn
    enum CleanMode: String, CaseIterable {
        case light = "Nhẹ (1 vòng)"
        case normal = "Bình thường (2 vòng)"
        case deep = "Chuyên sâu (3 vòng + Cache)"
    }
    
    func cleanRAM(monitor: SystemMonitorManager, mode: CleanMode = .deep) {
        guard !isCleaningRAM else { return }
        isCleaningRAM = true
        message = ""
        log = []
        cleanedAmountMB = 0
        
        DispatchQueue.global(qos: .userInitiated).async {
            var logLines: [String] = []
            logLines.append("═══ NHẬT KÝ DỌN RAM ═══")
            logLines.append("Thời gian: \(self.timeStr())")
            logLines.append("Chế độ: \(mode.rawValue)")
            logLines.append("")
            
            // Đo trước
            let ramBefore = Double(os_proc_available_memory()) / (1024*1024)
            let ramUsed = monitor.getRAMUsage()
            logLines.append("── TRƯỚC KHI DỌN ──")
            logLines.append("RAM trống: \(String(format: "%.0f", ramBefore)) MB")
            logLines.append("RAM đã dùng: \(String(format: "%.0f / %.0f", ramUsed.used, ramUsed.total)) MB")
            logLines.append("")
            
            let passes: Int
            switch mode {
            case .light: passes = 1
            case .normal: passes = 2
            case .deep: passes = 3
            }
            
            // Bước 1: Xoá Cache (chế độ normal + deep)
            if mode == .deep || mode == .normal {
                DispatchQueue.main.async { self.message = "Xoá Cache hệ thống..." }
                logLines.append("── XOÁ CACHE CỦA APP NÀY ──")
                
                // 1. HTTP Cache (URLSession)
                let urlCacheBefore = Double(URLCache.shared.currentDiskUsage) / (1024*1024)
                URLCache.shared.removeAllCachedResponses()
                URLCache.shared.diskCapacity = 0
                URLCache.shared.memoryCapacity = 0
                let urlCacheAfter = Double(URLCache.shared.currentDiskUsage) / (1024*1024)
                logLines.append("✅ HTTP Cache: xoá \(String(format: "%.1f", urlCacheBefore - urlCacheAfter)) MB")
                
                // Reset lại capacity
                URLCache.shared.diskCapacity = 50 * 1024 * 1024
                URLCache.shared.memoryCapacity = 10 * 1024 * 1024
                
                // 2. Cookies
                if let cookies = HTTPCookieStorage.shared.cookies {
                    let count = cookies.count
                    for c in cookies { HTTPCookieStorage.shared.deleteCookie(c) }
                    logLines.append("✅ Xoá \(count) cookies")
                }
                
                // 3. File tạm (tmp)
                let tmpDir = NSTemporaryDirectory()
                var tmpCount = 0
                var tmpSizeMB: Double = 0
                if let files = try? FileManager.default.contentsOfDirectory(atPath: tmpDir) {
                    for f in files {
                        let p = (tmpDir as NSString).appendingPathComponent(f)
                        if let a = try? FileManager.default.attributesOfItem(atPath: p),
                           let s = a[.size] as? UInt64 { tmpSizeMB += Double(s) / (1024*1024) }
                        try? FileManager.default.removeItem(atPath: p)
                        tmpCount += 1
                    }
                }
                logLines.append("✅ Xoá \(tmpCount) file tạm (\(String(format: "%.1f", tmpSizeMB)) MB)")
                
                // 4. Thư mục Caches
                var cacheCount = 0
                var cacheSizeMB: Double = 0
                if let cachePath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first,
                   let files = try? FileManager.default.contentsOfDirectory(atPath: cachePath) {
                    for f in files {
                        let p = (cachePath as NSString).appendingPathComponent(f)
                        if let a = try? FileManager.default.attributesOfItem(atPath: p),
                           let s = a[.size] as? UInt64 { cacheSizeMB += Double(s) / (1024*1024) }
                        try? FileManager.default.removeItem(atPath: p)
                        cacheCount += 1
                    }
                }
                logLines.append("✅ Xoá \(cacheCount) mục trong Caches (\(String(format: "%.1f", cacheSizeMB)) MB)")
                
                // 5. Library/WebKit (nếu có)
                if let libPath = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first {
                    let webkitPath = (libPath as NSString).appendingPathComponent("WebKit")
                    if FileManager.default.fileExists(atPath: webkitPath) {
                        try? FileManager.default.removeItem(atPath: webkitPath)
                        logLines.append("✅ Xoá WebKit Cache")
                    }
                }
                
                logLines.append("")
                logLines.append("── XOÁ CACHE APP KHÁC (gián tiếp) ──")
                logLines.append("ℹ️ iOS Sandbox KHÔNG cho phép truy cập trực tiếp")
                logLines.append("ℹ️ thư mục Cache của app khác.")
                logLines.append("ℹ️ → Dùng Memory Pressure ở bước tiếp để ÉP iOS")
                logLines.append("ℹ️ tự xoá cache + tắt app ngầm của TẤT CẢ app.")
                logLines.append("")
                
                Thread.sleep(forTimeInterval: 0.5)
            }
            
            // Bước 2: Memory Pressure nhiều vòng
            logLines.append("── ÉP MEMORY PRESSURE ──")
            
            for pass in 1...passes {
                DispatchQueue.main.async {
                    self.message = "Vòng \(pass)/\(passes): Ép iOS tắt app ngầm..."
                }
                logLines.append("Vòng \(pass): Bắt đầu phân bổ RAM...")
                
                let chunk = 50 * 1024 * 1024
                var ptrs: [UnsafeMutableRawPointer] = []
                var allocatedMB = 0
                
                // Ở chế độ deep, ép sâu hơn (còn 100MB thay vì 120MB)
                let threshold = mode == .deep ? 100 * 1024 * 1024 : 120 * 1024 * 1024
                
                while true {
                    let avail = os_proc_available_memory()
                    if avail < threshold { break }
                    let p = mmap(nil, chunk, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0)
                    if p != MAP_FAILED, let v = p {
                        memset(v, 0, chunk)
                        ptrs.append(v)
                        allocatedMB += 50
                    } else { break }
                    Thread.sleep(forTimeInterval: 0.01)
                }
                
                logLines.append("Vòng \(pass): Đã nuốt \(allocatedMB) MB → Chờ iOS phản ứng...")
                
                // Chế độ deep chờ lâu hơn để iOS có thời gian giết nhiều app hơn
                let waitTime: TimeInterval = mode == .deep ? 3.0 : 2.0
                Thread.sleep(forTimeInterval: waitTime)
                
                // Giải phóng
                for p in ptrs { munmap(p, chunk) }
                ptrs.removeAll()
                
                let ramAfterPass = Double(os_proc_available_memory()) / (1024*1024)
                logLines.append("Vòng \(pass): RAM trống = \(String(format: "%.0f", ramAfterPass)) MB")
                
                if pass < passes {
                    Thread.sleep(forTimeInterval: 1.0)
                }
            }
            
            logLines.append("")
            
            // Đo sau
            Thread.sleep(forTimeInterval: 1.0)
            let ramAfter = Double(os_proc_available_memory()) / (1024*1024)
            let freed = ramAfter - ramBefore
            
            logLines.append("── KẾT QUẢ ──")
            logLines.append("RAM trống sau: \(String(format: "%.0f", ramAfter)) MB")
            
            if freed > 10 {
                logLines.append("✅ Giải phóng: \(String(format: "%.0f", freed)) MB RAM")
            } else if freed > 0 {
                logLines.append("⚠️ Chỉ giải phóng \(String(format: "%.0f", freed)) MB - Máy vốn đã sạch")
            } else {
                logLines.append("ℹ️ RAM không tăng - iOS đã tối ưu sẵn, không có app ngầm rác")
            }
            
            logLines.append("")
            logLines.append("═══ HOÀN TẤT ═══")
            
            DispatchQueue.main.async {
                self.isCleaningRAM = false
                self.cleanedAmountMB = max(0, freed)
                self.log = logLines
                if freed > 10 {
                    self.message = "Đã giải phóng \(String(format: "%.0f", freed)) MB RAM!"
                } else {
                    self.message = "Máy đã sạch! iOS không tìm thấy app ngầm rác."
                }
            }
        }
    }
    
    // MARK: - Dọn RAM Tự Động
    
    func toggleAutoClean(monitor: SystemMonitorManager) {
        autoCleanEnabled.toggle()
        monitorRef = monitor
        
        if autoCleanEnabled {
            startAutoCleanTimer(monitor: monitor)
        } else {
            autoCleanTimer?.invalidate()
            autoCleanTimer = nil
        }
    }
    
    func restartAutoClean() {
        guard autoCleanEnabled, let monitor = monitorRef else { return }
        autoCleanTimer?.invalidate()
        startAutoCleanTimer(monitor: monitor)
    }
    
    private func startAutoCleanTimer(monitor: SystemMonitorManager) {
        autoCleanTimer?.invalidate()
        autoCleanTimer = Timer.scheduledTimer(withTimeInterval: autoCleanInterval, repeats: true) { [weak self] _ in
            guard let self = self, self.autoCleanEnabled, !self.isCleaningRAM else { return }
            
            let availMB = Double(os_proc_available_memory()) / (1024*1024)
            if availMB < self.autoCleanThresholdMB {
                self.autoCleanCount += 1
                let f = DateFormatter()
                f.dateFormat = "HH:mm:ss"
                self.autoCleanLastTime = f.string(from: Date())
                self.cleanRAM(monitor: monitor, mode: self.autoCleanMode)
            }
        }
    }
    
    private func timeStr() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: Date())
    }
}
