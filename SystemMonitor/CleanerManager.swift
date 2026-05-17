import Foundation
import Combine
import os

class CleanerManager: ObservableObject {
    @Published var isCleaningRAM: Bool = false
    @Published var cleanedAmountMB: Double = 0.0
    
    private var memoryHog: [UnsafeMutableRawPointer] = []
    
    func cleanRAM() {
        guard !isCleaningRAM else { return }
        isCleaningRAM = true
        self.cleanedAmountMB = 0.0
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Lấy lượng RAM tối đa mà app có thể dùng trước khi bị iOS "giết"
            let availableMemory = os_proc_available_memory()
            
            // Ép phân bổ 85% số RAM khả dụng để báo động hệ thống (Memory Pressure)
            // Khi iOS thấy RAM cạn kiệt, nó sẽ tự động thanh trừng các app ngầm (Facebook, TikTok...)
            let targetAllocation = Double(availableMemory) * 0.85
            let chunkSize = 50 * 1024 * 1024 // 50MB
            var allocated: Double = 0
            
            while allocated < targetAllocation {
                if let ptr = malloc(chunkSize) {
                    memset(ptr, 0, chunkSize) // Bắt buộc hệ thống cấp RAM thực
                    self.memoryHog.append(ptr)
                    allocated += Double(chunkSize)
                } else {
                    break
                }
                Thread.sleep(forTimeInterval: 0.02)
            }
            
            // Giữ mảng RAM này trong 2 giây để iOS có thời gian dọn dẹp các tiến trình ngầm
            Thread.sleep(forTimeInterval: 2.0)
            
            // Dọn dẹp mảng RAM rác, trả lại RAM sạch cho hệ thống
            for ptr in self.memoryHog {
                free(ptr)
            }
            self.memoryHog.removeAll()
            
            DispatchQueue.main.async {
                self.isCleaningRAM = false
                self.cleanedAmountMB = allocated / (1024 * 1024)
            }
        }
    }
}
