import SwiftUI

struct DiagnosticView: View {
    @StateObject private var diagnostic = DiagnosticManager()
    @ObservedObject var monitor: SystemMonitorManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if diagnostic.isScanComplete {
                    scoreSection
                    statsSection
                }
                scanButton
                if diagnostic.isScanComplete && diagnostic.totalFixable > 0 {
                    fixButton
                }
                if !diagnostic.fixLog.isEmpty {
                    fixLogSection
                }
                if diagnostic.isScanComplete {
                    resultsList
                }
                Spacer().frame(height: 30)
            }
            .padding(.top)
        }
        .navigationTitle("Chẩn Đoán & Sửa Lỗi")
    }
    
    var scoreSection: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 15)
                    .frame(width: 150, height: 150)
                Circle()
                    .trim(from: 0, to: CGFloat(diagnostic.healthScore) / 100.0)
                    .stroke(colorForScore(diagnostic.healthScore), style: StrokeStyle(lineWidth: 15, lineCap: .round))
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("\(diagnostic.healthScore)")
                        .font(.system(size: 45, weight: .bold, design: .rounded))
                        .foregroundColor(colorForScore(diagnostic.healthScore))
                    Text("điểm").font(.caption).foregroundColor(.gray)
                }
            }
            Text(healthLabel(diagnostic.healthScore))
                .font(.title3).bold()
                .foregroundColor(colorForScore(diagnostic.healthScore))
        }
    }
    
    var statsSection: some View {
        HStack(spacing: 20) {
            statBadge(count: diagnostic.results.filter { $0.status == .good }.count, label: "Tốt", color: .green)
            statBadge(count: diagnostic.results.filter { $0.status == .warning }.count, label: "Cảnh báo", color: .orange)
            statBadge(count: diagnostic.results.filter { $0.status == .critical }.count, label: "Lỗi", color: .red)
        }
    }
    
    var scanButton: some View {
        Group {
            if diagnostic.isScanning {
                VStack(spacing: 10) {
                    ProgressView(value: diagnostic.scanProgress).padding(.horizontal)
                    Text(diagnostic.currentScanStep).font(.footnote).foregroundColor(.gray)
                }.padding()
            } else {
                Button(action: { diagnostic.runFullDiagnostic(monitor: monitor) }) {
                    HStack {
                        Image(systemName: "stethoscope")
                        Text(diagnostic.isScanComplete ? "Quét Lại" : "Bắt Đầu Chẩn Đoán")
                    }
                    .font(.headline).frame(maxWidth: .infinity).padding()
                    .background(Color.purple).foregroundColor(.white).cornerRadius(12)
                }.padding(.horizontal)
            }
        }
    }
    
    var fixButton: some View {
        VStack(spacing: 8) {
            Button(action: { diagnostic.autoFixAll(monitor: monitor) }) {
                HStack {
                    Image(systemName: "wrench.and.screwdriver.fill")
                    Text(diagnostic.isFixingAll ? "Đang sửa..." : "Sửa \(diagnostic.totalFixable) Lỗi Tự Động")
                }
                .font(.headline).frame(maxWidth: .infinity).padding()
                .background(diagnostic.isFixingAll ? Color.gray : Color.green)
                .foregroundColor(.white).cornerRadius(12)
            }
            .disabled(diagnostic.isFixingAll)
            .padding(.horizontal)
            
            if !diagnostic.fixProgress.isEmpty {
                Text(diagnostic.fixProgress).font(.caption).foregroundColor(.orange).padding(.horizontal)
            }
        }
    }
    
    var resultsList: some View {
        let sorted = diagnostic.results.sorted { statusOrder($0.status) < statusOrder($1.status) }
        return ForEach(sorted) { item in
            DiagnosticRowView(item: item)
                .padding(.horizontal)
        }
    }
    
    var fixLogSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("NHẬT KÝ SỬA LỖI").font(.subheadline).bold().foregroundColor(Color(red: 0, green: 0.8, blue: 1))
            ForEach(diagnostic.fixLog, id: \.self) { line in
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
    
    func statBadge(count: Int, label: String, color: Color) -> some View {
        VStack {
            Text("\(count)").font(.title2).bold().foregroundColor(color)
            Text(label).font(.caption2).foregroundColor(.gray)
        }
        .frame(width: 70).padding(.vertical, 8)
        .background(color.opacity(0.1)).cornerRadius(10)
    }
    
    func colorForScore(_ s: Int) -> Color {
        if s >= 80 { return .green }
        if s >= 50 { return .orange }
        return .red
    }
    
    func healthLabel(_ s: Int) -> String {
        if s >= 90 { return "Máy rất khoẻ mạnh!" }
        if s >= 70 { return "Máy hoạt động ổn định" }
        if s >= 50 { return "Máy có một số vấn đề" }
        return "Máy cần sửa chữa NGAY!"
    }
    
    func statusOrder(_ s: DiagnosticStatus) -> Int {
        switch s {
        case .critical: return 0
        case .warning: return 1
        case .good: return 2
        }
    }
}

struct DiagnosticRowView: View {
    let item: DiagnosticItem
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.icon)
                .font(.title2)
                .foregroundColor(statusColor)
                .frame(width: 35)
            
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(item.name).font(.subheadline).bold()
                    Spacer()
                    HStack(spacing: 4) {
                        Circle().fill(statusColor).frame(width: 8, height: 8)
                        Text(statusText).font(.caption2).foregroundColor(statusColor)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(statusColor.opacity(0.15)).cornerRadius(8)
                }
                
                Text(item.detail).font(.caption).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                if item.canAutoFix && item.status != .good {
                    HStack(spacing: 4) {
                        Image(systemName: "wrench.fill").font(.caption2)
                        Text(item.fixAction).font(.caption2)
                    }.foregroundColor(.blue).padding(.top, 2)
                } else if !item.canAutoFix && item.status != .good && !item.fixAction.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.point.right.fill").font(.caption2)
                        Text(item.fixAction).font(.caption2)
                    }.foregroundColor(.purple).padding(.top, 2)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    var statusColor: Color {
        switch item.status {
        case .good: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
    
    var statusText: String {
        switch item.status {
        case .good: return "Tốt"
        case .warning: return "Cảnh báo"
        case .critical: return "Lỗi"
        }
    }
}
