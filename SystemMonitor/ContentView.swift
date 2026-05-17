import SwiftUI

struct ContentView: View {
    @StateObject private var monitor = SystemMonitorManager()
    @StateObject private var cleaner = CleanerManager()
    
    var body: some View {
        TabView {
            // TAB 1: Giám Sát
            NavigationView {
                List {
                    Section(header: Text("Chẩn Đoán Lỗi & Thông Số Cơ Bản")) {
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
                            Text("Xung nhịp tối đa")
                            Spacer()
                            if monitor.cpuFrequency > 0 {
                                Text("\(monitor.cpuFrequency / 1000000) MHz").bold()
                            } else {
                                Text("Bị Apple chặn").bold().foregroundColor(.red)
                            }
                        }
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
                            Text("Công suất sạc (Power)")
                            Spacer()
                            if monitor.chargingPower > 0 {
                                Text(String(format: "%.2f W", monitor.chargingPower)).bold()
                            } else {
                                Text("Bị Apple chặn / Đã rút").bold().foregroundColor(.red)
                            }
                        }
                        HStack {
                            Text("Độ chai pin (Battery Health)")
                            Spacer()
                            if monitor.batteryHealth > 0 {
                                Text(String(format: "%.1f %%", monitor.batteryHealth)).bold()
                            } else {
                                Text("Bị Apple chặn").bold().foregroundColor(.red)
                            }
                        }
                        HStack {
                            Text("Chu kỳ sạc (Cycle Count)")
                            Spacer()
                            if monitor.batteryCycles >= 0 {
                                Text("\(monitor.batteryCycles) lần").bold()
                            } else {
                                Text("Bị Apple chặn").bold().foregroundColor(.red)
                            }
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
            
            // TAB 2: Dọn Dẹp
            NavigationView {
                VStack(spacing: 30) {
                    Text("Cảnh báo: Tính năng này dùng phương pháp ép bộ nhớ, có thể làm nóng máy tạm thời.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    VStack(spacing: 15) {
                        Image(systemName: "memorychip")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                        Text("Dọn Dẹp Bộ Nhớ (RAM)")
                            .font(.headline)
                        
                        Button(action: {
                            cleaner.cleanRAM()
                        }) {
                            Text(cleaner.isCleaningRAM ? "Đang ép RAM..." : "Chạy Dọn RAM")
                                .bold()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(cleaner.isCleaningRAM ? Color.gray : Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .disabled(cleaner.isCleaningRAM)
                        
                        if cleaner.isCleaningRAM {
                            ProgressView()
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(15)
                    .padding(.horizontal)
                    
                    VStack(spacing: 15) {
                        Image(systemName: "trash.circle")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        Text("Dọn Rác Hệ Thống (Disk)")
                            .font(.headline)
                        
                        Button(action: {
                            if cleaner.isCleaningJunk {
                                cleaner.stopCleaningJunk()
                            } else {
                                cleaner.cleanJunk()
                            }
                        }) {
                            Text(cleaner.isCleaningJunk ? "Dừng Lấp Ổ Cứng" : "Ép Xoá Rác")
                                .bold()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(cleaner.isCleaningJunk ? Color.red : Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        
                        if cleaner.isCleaningJunk {
                            ProgressView("Đang lấp đầy ổ cứng...")
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(15)
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .navigationTitle("Dọn Dẹp (Thử Nghiệm)")
            }
            .tabItem {
                Image(systemName: "sparkles")
                Text("Dọn Dẹp")
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
