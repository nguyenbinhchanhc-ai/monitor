import SwiftUI

struct ContentView: View {
    @StateObject private var monitor = SystemMonitorManager()
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Bộ Xử Lý (CPU)")) {
                    HStack {
                        Text("Mức độ sử dụng")
                        Spacer()
                        Text(String(format: "%.1f %%", monitor.cpuUsage))
                            .foregroundColor(colorForUsage(monitor.cpuUsage))
                            .bold()
                    }
                    ProgressView(value: min(monitor.cpuUsage / 100.0, 1.0))
                        .accentColor(colorForUsage(monitor.cpuUsage))
                }
                
                Section(header: Text("Bộ Nhớ (RAM)")) {
                    HStack {
                        Text("Đã sử dụng")
                        Spacer()
                        Text(String(format: "%.0f MB / %.0f MB", monitor.usedRAM, monitor.totalRAM))
                            .foregroundColor(colorForUsage((monitor.usedRAM / max(monitor.totalRAM, 1)) * 100))
                            .bold()
                    }
                    ProgressView(value: min(monitor.usedRAM / max(monitor.totalRAM, 1), 1.0))
                        .accentColor(colorForUsage((monitor.usedRAM / max(monitor.totalRAM, 1)) * 100))
                }
                
                Section(header: Text("Pin & Nhiệt Độ")) {
                    HStack {
                        Text("Dung lượng Pin")
                        Spacer()
                        Text(monitor.batteryLevel >= 0 ? String(format: "%.0f %%", monitor.batteryLevel * 100) : "Không rõ")
                            .bold()
                    }
                    HStack {
                        Text("Trạng thái nhiệt")
                        Spacer()
                        Text(thermalStateString(monitor.thermalState))
                            .foregroundColor(colorForThermalState(monitor.thermalState))
                            .bold()
                    }
                }
            }
            .navigationTitle("Giám Sát Hệ Thống")
        }
    }
    
    func colorForUsage(_ usage: Double) -> Color {
        if usage < 50 { return .green }
        if usage < 80 { return .orange }
        return .red
    }
    
    func thermalStateString(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "Bình thường"
        case .fair: return "Hơi nóng"
        case .serious: return "Rất nóng"
        case .critical: return "Nguy hiểm"
        @unknown default: return "Không rõ"
        }
    }
    
    func colorForThermalState(_ state: ProcessInfo.ThermalState) -> Color {
        switch state {
        case .nominal: return .green
        case .fair: return .orange
        case .serious: return .red
        case .critical: return .purple
        @unknown default: return .primary
        }
    }
}
