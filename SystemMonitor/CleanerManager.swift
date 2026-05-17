import Foundation
import Combine
import os

class CleanerManager: ObservableObject {
    @Published var isCleaningRAM: Bool = false
    @Published var cleanedAmountMB: Double = 0.0
    @Published var message: String = ""
    
    func cleanRAM(monitor: SystemMonitorManager) {
        guard !isCleaningRAM else { return }
        isCleaningRAM = true
        self.message = "Bắt đầu phân tích RAM..."
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Đo RAM trước khi dọn
            let ramBefore = monitor.getRAMUsage().used
            
            var pointers: [UnsafeMutableRawPointer] = []
            let chunkSize = 50 * 1024 * 1024 // Cục 50MB
            var allocatedMB = 0
            
            // Vòng lặp nhồi RAM cho đến khi iOS báo động
            while true {
                let available = os_proc_available_memory()
                // Dừng lại khi app chỉ còn dưới 150MB được phép dùng để tránh tự sát (Crash)
                if available < 150 * 1024 * 1024 {
                    break
                }
                
                // Dùng mmap để ép iOS cấp phát vùng nhớ vật lý (không dùng malloc vì malloc dễ bị ảo)
                let ptr = mmap(nil, chunkSize, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0)
                if ptr != MAP_FAILED, let validPtr = ptr {
                    memset(validPtr, 0, chunkSize) // Ghi số 0 vào để ép RAM vật lý hoạt động
                    pointers.append(validPtr)
                    allocatedMB += 50
                    
                    DispatchQueue.main.async {
                        self.message = "Đang ép hệ thống: Nuốt \(allocatedMB) MB..."
                    }
                } else {
                    break
                }
                Thread.sleep(forTimeInterval: 0.05)
            }
            
            DispatchQueue.main.async {
                self.message = "Đang ép iOS chém app ngầm..."
            }
            
            // Đợi 2 giây để iOS có thời gian phát hiện thiếu RAM và đi giết các app ngầm
            Thread.sleep(forTimeInterval: 2.0)
            
            DispatchQueue.main.async {
                self.message = "Đang hoàn trả RAM cho hệ thống..."
            }
            
            // Dọn dẹp mảng RAM rác bằng munmap để OS nhận lại ngay lập tức
            for ptr in pointers {
                munmap(ptr, chunkSize)
            }
            pointers.removeAll()
            
            // Đợi 1 giây để OS cập nhật lại thông số RAM
            Thread.sleep(forTimeInterval: 1.0)
            
            let ramAfter = monitor.getRAMUsage().used
            let freed = ramBefore - ramAfter
            
            DispatchQueue.main.async {
                self.isCleaningRAM = false
                if freed > 10 { // Nếu dọn được hơn 10MB
                    self.cleanedAmountMB = freed
                    self.message = "Hoàn tất! Đã giải phóng \(String(format: "%.0f", freed)) MB RAM."
                } else {
                    self.cleanedAmountMB = 0
                    self.message = "Máy đã rất mượt, không có app ngầm rác nào để xoá!"
                }
            }
        }
    }
}
