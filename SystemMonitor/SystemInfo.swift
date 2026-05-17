import Foundation
import UIKit
import Combine

class SystemMonitorManager: ObservableObject {
    @Published var cpuUsage: Double = 0.0
    @Published var usedRAM: Double = 0.0
    @Published var totalRAM: Double = 0.0
    @Published var batteryLevel: Float = 0.0
    @Published var thermalState: ProcessInfo.ThermalState = .nominal
    
    private var timer: Timer?
    
    private var prevCpuInfo: processor_info_array_t?
    private var numPrevCpuInfo: mach_msg_type_number_t = 0
    
    init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        updateStats()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateStats()
        }
    }
    
    deinit {
        timer?.invalidate()
        if let prevInfo = prevCpuInfo {
            let prevSize = MemoryLayout<integer_t>.stride * Int(numPrevCpuInfo)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prevInfo), vm_size_t(prevSize))
        }
    }
    
    func updateStats() {
        self.cpuUsage = self.getCPUUsage()
        let ram = self.getRAMUsage()
        self.usedRAM = ram.used
        self.totalRAM = ram.total
        self.batteryLevel = UIDevice.current.batteryLevel
        self.thermalState = ProcessInfo.processInfo.thermalState
    }
    
    func getCPUUsage() -> Double {
        var cpuInfo: processor_info_array_t!
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCPUs: natural_t = 0
        
        let kr = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUs, &cpuInfo, &numCpuInfo)
        
        if kr == KERN_SUCCESS {
            var inUse: Double = 0.0
            var total: Double = 0.0
            
            if let prevInfo = prevCpuInfo {
                for i in 0..<Int(numCPUs) {
                    let userNow = Double(cpuInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_USER)])
                    let sysNow = Double(cpuInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_SYSTEM)])
                    let niceNow = Double(cpuInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_NICE)])
                    let inUseNow = userNow + sysNow + niceNow
                    
                    let userPrev = Double(prevInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_USER)])
                    let sysPrev = Double(prevInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_SYSTEM)])
                    let nicePrev = Double(prevInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_NICE)])
                    let inUsePrev = userPrev + sysPrev + nicePrev
                    
                    let idleNow = Double(cpuInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_IDLE)])
                    let idlePrev = Double(prevInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_IDLE)])
                    
                    let useDelta = Double(inUseNow - inUsePrev)
                    let idleDelta = Double(idleNow - idlePrev)
                    let totalDelta = useDelta + idleDelta
                    
                    if totalDelta > 0 {
                        inUse += useDelta
                        total += totalDelta
                    }
                }
                
                let prevSize = MemoryLayout<integer_t>.stride * Int(numPrevCpuInfo)
                vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prevInfo), vm_size_t(prevSize))
            }
            
            prevCpuInfo = cpuInfo
            numPrevCpuInfo = numCpuInfo
            
            if total > 0 {
                return (inUse / total) * 100.0
            }
        }
        return 0.0
    }
    
    func getRAMUsage() -> (used: Double, total: Double) {
        var pagesize: vm_size_t = 0
        host_page_size(mach_host_self(), &pagesize)
        
        var vm_stat: vm_statistics64 = vm_statistics64()
        var count: mach_msg_type_number_t = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &vm_stat) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        let total = ProcessInfo.processInfo.physicalMemory
        
        if result == KERN_SUCCESS {
            let active = Double(vm_stat.active_count) * Double(pagesize)
            let wired = Double(vm_stat.wire_count) * Double(pagesize)
            let compressed = Double(vm_stat.compressor_page_count) * Double(pagesize)
            let used = active + wired + compressed
            return (used: used / (1024 * 1024), total: Double(total) / (1024 * 1024))
        }
        
        return (0, Double(total) / (1024 * 1024))
    }
}
