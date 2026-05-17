import Foundation

struct SecurityReport {
    var isRoot: Bool
    var isSandboxed: Bool
    var isJailbroken: Bool
    
    var allowedPermissions: [String]
    var blockedPermissions: [String]
}

class SecurityScannerManager: ObservableObject {
    @Published var isScanning = false
    @Published var report: SecurityReport?
    
    func runScan() {
        isScanning = true
        report = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            // 1. Quét quyền Root (Kiểm tra xem app có chạy với đặc quyền tối cao không)
            let root = getuid() == 0
            
            // 2. Quét ranh giới Sandbox (Thử ghi dữ liệu lén lút vào phân vùng hệ thống)
            let testPath = "/private/var/sandbox_test.txt"
            var sandboxed = true
            do {
                try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
                sandboxed = false // Ghi thành công tức là đã vượt ngục
                try FileManager.default.removeItem(atPath: testPath)
            } catch {
                sandboxed = true // Bị chặn tức là đang trong Hộp Cát
            }
            
            // 3. Quét phát hiện File bẻ khóa/TrollStore
            let jbPaths = [
                "/Applications/Cydia.app",
                "/Applications/TrollStore.app",
                "/Applications/Sileo.app",
                "/var/bin/bash",
                "/usr/sbin/sshd",
                "/etc/apt"
            ]
            var jailbroken = false
            for path in jbPaths {
                if FileManager.default.fileExists(atPath: path) {
                    jailbroken = true
                    break
                }
            }
            
            // Lập danh sách quyền hạn
            var allowed: [String] = [
                "Đọc thông số CPU, RAM, Disk",
                "Phân bổ và Ép buộc RAM vật lý (mmap)",
                "Kết nối mạng (Network)",
                "Đọc/Ghi dữ liệu trong hộp cát (App Sandbox)"
            ]
            var blocked: [String] = [
                "Truy cập phân vùng hệ thống lõi (/System)",
                "Tắt trực tiếp ứng dụng khác (Kill PID)",
                "Can thiệp vào dữ liệu của ứng dụng khác",
                "Đọc thông số nhạy cảm (Độ chai pin, Xung nhịp CPU)"
            ]
            
            if !sandboxed {
                allowed.append("Ghi dữ liệu tự do ngoài hệ thống (RootFS)")
                blocked.removeAll { $0 == "Truy cập phân vùng hệ thống lõi (/System)" }
            }
            
            let finalReport = SecurityReport(isRoot: root, isSandboxed: sandboxed, isJailbroken: jailbroken, allowedPermissions: allowed, blockedPermissions: blocked)
            
            // Giả lập độ trễ quét để người dùng thấy rõ quá trình
            Thread.sleep(forTimeInterval: 1.5)
            
            DispatchQueue.main.async {
                self.report = finalReport
                self.isScanning = false
            }
        }
    }
}
