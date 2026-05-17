import Foundation
import Combine

class CleanerManager: ObservableObject {
    @Published var isCleaningRAM: Bool = false
    @Published var isCleaningJunk: Bool = false
    
    private var memoryHog: [UnsafeMutableRawPointer] = []
    
    func cleanRAM() {
        guard !isCleaningRAM else { return }
        isCleaningRAM = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let chunkSize = 50 * 1024 * 1024 // 50MB
            
            for _ in 0..<30 { // Cố tình phân bổ 1.5GB để ép OS dọn dẹp RAM
                if let ptr = malloc(chunkSize) {
                    memset(ptr, 0, chunkSize) // Bắt buộc hệ thống cấp RAM thực
                    self.memoryHog.append(ptr)
                }
                Thread.sleep(forTimeInterval: 0.1) // Ngủ một chút để tránh bị kill vì phân bổ quá nhanh
            }
            
            // Dọn dẹp mảng RAM ảo
            for ptr in self.memoryHog {
                free(ptr)
            }
            self.memoryHog.removeAll()
            
            DispatchQueue.main.async {
                self.isCleaningRAM = false
            }
        }
    }
    
    func cleanJunk() {
        guard !isCleaningJunk else { return }
        isCleaningJunk = true
        
        DispatchQueue.global(qos: .background).async {
            let fileManager = FileManager.default
            let cachePath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
            
            var filePaths: [String] = []
            let chunkSize = 50 * 1024 * 1024 // 50MB
            let data = Data(count: chunkSize)
            
            var diskIsFull = false
            var fileIndex = 0
            
            while !diskIsFull && self.isCleaningJunk {
                let filePath = (cachePath as NSString).appendingPathComponent("junk_filler_\(fileIndex).tmp")
                do {
                    try data.write(to: URL(fileURLWithPath: filePath), options: .atomic)
                    filePaths.append(filePath)
                    fileIndex += 1
                    
                    let attrs = try fileManager.attributesOfFileSystem(forPath: NSHomeDirectory())
                    if let freeSpace = attrs[.systemFreeSize] as? NSNumber {
                        let freeMB = freeSpace.doubleValue / (1024 * 1024)
                        if freeMB < 200 { 
                            diskIsFull = true // Ổ cứng gần đầy, OS sẽ tự kích hoạt xoá Cache
                        }
                    }
                } catch {
                    diskIsFull = true // Ghi lỗi tức là ổ cứng đã báo full
                }
            }
            
            // Xoá file rác ảo
            for path in filePaths {
                try? fileManager.removeItem(atPath: path)
            }
            
            DispatchQueue.main.async {
                self.isCleaningJunk = false
            }
        }
    }
    
    func stopCleaningJunk() {
        isCleaningJunk = false
    }
}
