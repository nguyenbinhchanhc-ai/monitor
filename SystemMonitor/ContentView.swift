import SwiftUI

struct ContentView: View {
    @StateObject private var monitor = SystemMonitorManager()
    @StateObject private var cleaner = CleanerManager()
    @ObservedObject private var bgKeepAlive = BackgroundKeepAlive.shared
    
    var body: some View {
        TabView {
            // TAB 1: Giám Sát
            NavigationView {
                List {
                    Section(header: Text("Thông Số Cơ Bản")) {
                        HStack {
                            Text("Dòng máy")
                            Spacer()
                            Text(monitor.deviceModel).bold()
                        }
                        HStack {
                            Text("Thời gian hoạt động")
                            Spacer()
                            Text(monitor.uptime).bold()
                        }
                        HStack {
                            Text("Bộ nhớ trong (Disk)")
                            Spacer()
                            Text(String(format: "%.1f GB / %.1f GB", monitor.usedDisk, monitor.totalDisk))
                                .bold()
                        }
                        ProgressView(value: max(0.0, min(monitor.usedDisk / max(monitor.totalDisk, 1), 1.0)))
                            .accentColor(.blue)
                        
                        HStack {
                            Text("Chế độ tiết kiệm pin")
                            Spacer()
                            Text(monitor.lowPowerMode ? "Đang bật" : "Tắt")
                                .foregroundColor(monitor.lowPowerMode ? .orange : .green)
                                .bold()
                        }
                    }

                    Section(header: Text("Bộ Xử Lý (CPU)")) {
                        HStack {
                            Text("Mức độ sử dụng")
                            Spacer()
                            Text(String(format: "%.1f %%", monitor.cpuUsage))
                                .foregroundColor(colorForUsage(monitor.cpuUsage))
                                .bold()
                        }
                        ProgressView(value: max(0.0, min(monitor.cpuUsage / 100.0, 1.0)))
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
                        ProgressView(value: max(0.0, min(monitor.usedRAM / max(monitor.totalRAM, 1), 1.0)))
                            .accentColor(colorForUsage((monitor.usedRAM / max(monitor.totalRAM, 1)) * 100))
                    }
                    
                    Section(header: Text("Pin & Nhiệt Độ")) {
                        HStack {
                            Text("Mức sạc (API Apple)")
                            Spacer()
                            if monitor.batteryLevel >= 0 {
                                Text(String(format: "%.0f %%", monitor.batteryLevel * 100))
                                    .bold()
                            } else {
                                Text("Không rõ").bold()
                            }
                        }
                        HStack {
                            Text("Giá trị thô (Raw)")
                            Spacer()
                            if monitor.batteryLevel >= 0 {
                                Text(String(format: "%.2f", monitor.batteryLevel))
                                    .bold()
                                    .foregroundColor(.gray)
                            } else {
                                Text("-1").bold().foregroundColor(.gray)
                            }
                        }
                        Text("⚠️ Apple làm tròn pin theo bước 5% (95→100). Con số chính xác trên thanh trạng thái dùng API riêng mà app bên thứ 3 không được phép truy cập.")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        HStack {
                            Text("Trạng thái nhiệt")
                            Spacer()
                            Text(thermalStateString(monitor.thermalState))
                                .foregroundColor(colorForThermalState(monitor.thermalState))
                                .bold()
                        }
                    }
                    
                    Section(header: Text("Chạy Ngầm")) {
                        HStack {
                            Image(systemName: bgKeepAlive.isBackgroundEnabled ? "location.fill" : "location.slash")
                                .foregroundColor(bgKeepAlive.isBackgroundEnabled ? .green : .gray)
                            Toggle("Giữ app sống khi ẩn", isOn: Binding(
                                get: { bgKeepAlive.isBackgroundEnabled },
                                set: { newValue in
                                    if newValue { bgKeepAlive.startBackground() }
                                    else { bgKeepAlive.stopBackground() }
                                }
                            ))
                        }
                        Text(bgKeepAlive.status)
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("Dùng quyền Vị trí (độ chính xác thấp nhất) để iOS không tự tắt app. Hao pin rất ít.")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                .navigationTitle("Giám Sát")
            }
            .tabItem {
                Image(systemName: "cpu")
                Text("Giám Sát")
            }
            
            // TAB 2: Tối Ưu RAM
            NavigationView {
                CleanerView(cleaner: cleaner, monitor: monitor)
            }
            .tabItem {
                Image(systemName: "bolt.fill")
                Text("Tối Ưu")
            }
            
            // TAB 3: Chẩn Đoán & Sửa Lỗi
            NavigationView {
                DiagnosticView(monitor: monitor)
            }
            .tabItem {
                Image(systemName: "stethoscope")
                Text("Chẩn Đoán")
            }
            
            // TAB 4: Đặc Quyền
            NavigationView {
                SecurityScannerView()
            }
            .tabItem {
                Image(systemName: "lock.shield.fill")
                Text("Đặc Quyền")
            }
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
