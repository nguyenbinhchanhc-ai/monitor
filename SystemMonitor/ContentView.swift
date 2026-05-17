import SwiftUI

struct ContentView: View {
    @StateObject private var monitor = SystemMonitorManager()
    @StateObject private var cleaner = CleanerManager()
    
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
                            Text("Mức sạc hiện tại")
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
                .navigationTitle("Giám Sát")
            }
            .tabItem {
                Image(systemName: "cpu")
                Text("Giám Sát")
            }
            
            // TAB 2: Tối Ưu RAM
            NavigationView {
                VStack(spacing: 30) {
                    Text("Cơ chế giải phóng RAM: Kích hoạt cảnh báo bộ nhớ (Memory Pressure) buộc hệ điều hành tự động thu hồi RAM và tắt các tiến trình chạy ngầm không cần thiết.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    VStack(spacing: 15) {
                        Image(systemName: "memorychip")
                            .font(.system(size: 50))
                            .foregroundColor(.green)
                            .padding(.bottom, 10)
                        
                        Text("Tối Ưu & Giải Phóng RAM")
                            .font(.title3)
                            .bold()
                        
                        if !cleaner.message.isEmpty {
                            Text(cleaner.message)
                                .font(.footnote)
                                .foregroundColor(cleaner.cleanedAmountMB > 0 ? .green : .gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        Button(action: {
                            cleaner.cleanRAM(monitor: monitor)
                        }) {
                            Text(cleaner.isCleaningRAM ? "Đang xử lý..." : "Dọn Dẹp Ngay")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(cleaner.isCleaningRAM ? Color.gray : Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .disabled(cleaner.isCleaningRAM)
                        
                        if cleaner.isCleaningRAM {
                            ProgressView()
                                .padding(.top, 10)
                        }
                    }
                    .padding(25)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(20)
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .navigationTitle("Tối Ưu (Tắt App Ngầm)")
            }
            .tabItem {
                Image(systemName: "bolt.fill")
                Text("Tối Ưu")
            }
            
            // TAB 3: Đặc Quyền
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
