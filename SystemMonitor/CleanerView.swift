import SwiftUI
import os

struct CleanerView: View {
    @ObservedObject var cleaner: CleanerManager
    @ObservedObject var monitor: SystemMonitorManager
    @State private var selectedMode: CleanerManager.CleanMode = .deep
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ramStatusCard
                modeSelector
                cleanButton
                autoCleanSection
                if !cleaner.log.isEmpty {
                    logSection
                }
                Spacer().frame(height: 20)
            }
            .padding(.top)
        }
        .navigationTitle("Tối Ưu RAM")
    }
    
    var ramStatusCard: some View {
        VStack(spacing: 10) {
            let availMB = Double(os_proc_available_memory()) / (1024*1024)
            HStack {
                VStack(alignment: .leading) {
                    Text("RAM Trống").font(.caption).foregroundColor(.gray)
                    Text("\(String(format: "%.0f", availMB)) MB")
                        .font(.title2).bold()
                        .foregroundColor(availMB > 500 ? .green : (availMB > 200 ? .orange : .red))
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Đã dùng").font(.caption).foregroundColor(.gray)
                    Text("\(String(format: "%.0f / %.0f", monitor.usedRAM, monitor.totalRAM)) MB")
                        .font(.subheadline).bold()
                }
            }
            ProgressView(value: max(0, min(monitor.usedRAM / max(monitor.totalRAM, 1), 1.0)))
                .accentColor(monitor.usedRAM / max(monitor.totalRAM, 1) > 0.8 ? .red : .green)
            
            if !cleaner.message.isEmpty {
                Text(cleaner.message)
                    .font(.caption)
                    .foregroundColor(cleaner.cleanedAmountMB > 0 ? .green : .gray)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    var modeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Chế độ dọn dẹp").font(.subheadline).bold()
            Picker("Mode", selection: $selectedMode) {
                ForEach(CleanerManager.CleanMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            
            Text(modeDescription)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding(.horizontal)
    }
    
    var modeDescription: String {
        switch selectedMode {
        case .light:
            return "1 vòng Memory Pressure. Nhanh, ít hiệu quả."
        case .normal:
            return "2 vòng Memory Pressure. Cân bằng tốc độ và hiệu quả."
        case .deep:
            return "3 vòng Memory Pressure + Xoá Cache/Cookie/File tạm. Sạch nhất, mất ~15 giây."
        }
    }
    
    var cleanButton: some View {
        VStack(spacing: 8) {
            Button(action: {
                cleaner.cleanRAM(monitor: monitor, mode: selectedMode)
            }) {
                HStack {
                    Image(systemName: "bolt.fill")
                    Text(cleaner.isCleaningRAM ? "Đang dọn dẹp..." : "Dọn RAM Ngay")
                }
                .font(.headline).frame(maxWidth: .infinity).padding()
                .background(cleaner.isCleaningRAM ? Color.gray : Color.green)
                .foregroundColor(.white).cornerRadius(12)
            }
            .disabled(cleaner.isCleaningRAM)
            .padding(.horizontal)
            
            if cleaner.isCleaningRAM {
                ProgressView().padding(.top, 5)
            }
        }
    }
    
    var autoCleanSection: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .foregroundColor(.blue)
                Text("Dọn RAM Tự Động").font(.subheadline).bold()
                Spacer()
                Toggle("", isOn: Binding(
                    get: { cleaner.autoCleanEnabled },
                    set: { _ in cleaner.toggleAutoClean(monitor: monitor) }
                ))
            }
            
            if cleaner.autoCleanEnabled {
                HStack {
                    Text("Ngưỡng kích hoạt:")
                        .font(.caption).foregroundColor(.gray)
                    Spacer()
                    Text("Khi RAM trống < \(Int(cleaner.autoCleanThresholdMB)) MB")
                        .font(.caption).foregroundColor(.orange)
                }
                HStack {
                    Text("Tần suất kiểm tra:")
                        .font(.caption).foregroundColor(.gray)
                    Spacer()
                    Text("Mỗi 30 giây")
                        .font(.caption).foregroundColor(.blue)
                }
                if cleaner.autoCleanCount > 0 {
                    HStack {
                        Text("Số lần đã tự dọn:")
                            .font(.caption).foregroundColor(.gray)
                        Spacer()
                        Text("\(cleaner.autoCleanCount) lần")
                            .font(.caption).bold().foregroundColor(.green)
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    var logSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("NHẬT KÝ DỌN DẸP").font(.subheadline).bold().foregroundColor(Color(red: 0, green: 0.8, blue: 1))
            ForEach(cleaner.log, id: \.self) { line in
                Text(line)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(logColor(line))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    func logColor(_ line: String) -> Color {
        if line.contains("✅") { return .green }
        if line.contains("⚠️") { return .orange }
        if line.contains("ℹ️") { return .gray }
        if line.contains("══") || line.contains("──") { return Color(red: 0, green: 0.8, blue: 1) }
        return .white
    }
}
