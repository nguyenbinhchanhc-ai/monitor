import SwiftUI

struct DiagnosticView: View {
    @StateObject private var diagnostic = DiagnosticManager()
    @ObservedObject var monitor: SystemMonitorManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                // ====== ĐIỂM SỨC KHOẺ ======
                if diagnostic.isScanComplete {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 15)
                            .frame(width: 150, height: 150)
                        Circle()
                            .trim(from: 0, to: CGFloat(diagnostic.healthScore) / 100.0)
                            .stroke(
                                colorForScore(diagnostic.healthScore),
                                style: StrokeStyle(lineWidth: 15, lineCap: .round)
                            )
                            .frame(width: 150, height: 150)
                            .rotationEffect(.degrees(-90))
                        
                        VStack(spacing: 2) {
                            Text("\(diagnostic.healthScore)")
                                .font(.system(size: 45, weight: .bold, design: .rounded))
                                .foregroundColor(colorForScore(diagnostic.healthScore))
                            Text("điểm")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.top, 10)
                    
                    Text(healthLabel(diagnostic.healthScore))
                        .font(.title3).bold()
                        .foregroundColor(colorForScore(diagnostic.healthScore))
                    
                    // Thống kê nhanh
                    HStack(spacing: 20) {
                        statBadge(count: diagnostic.results.filter { $0.status == .good }.count, label: "Tốt", color: .green)
                        statBadge(count: diagnostic.results.filter { $0.status == .warning }.count, label: "Cảnh báo", color: .orange)
                        statBadge(count: diagnostic.results.filter { $0.status == .critical }.count, label: "Lỗi", color: .red)
                    }
                }
                
                // ====== NÚT QUÉT ======
                if diagnostic.isScanning {
                    VStack(spacing: 10) {
                        ProgressView(value: diagnostic.scanProgress)
                            .padding(.horizontal)
                        Text(diagnostic.currentScanStep)
                            .font(.footnote)
                            .foregroundColor(.gray)
                    }
                    .padding()
                } else {
                    Button(action: {
                        diagnostic.runFullDiagnostic(monitor: monitor)
                    }) {
                        HStack {
                            Image(systemName: "stethoscope")
                            Text(diagnostic.isScanComplete ? "Quét Lại Hệ Thống" : "Bắt Đầu Chẩn Đoán")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                
                // ====== NÚT SỬA TẤT CẢ ======
                if diagnostic.isScanComplete && diagnostic.totalFixable > 0 {
                    VStack(spacing: 8) {
                        Button(action: {
                            diagnostic.autoFixAll(monitor: monitor)
                        }) {
                            HStack {
                                Image(systemName: "wrench.and.screwdriver.fill")
                                Text(diagnostic.isFixingAll ? "Đang sửa \(diagnostic.fixedCount)/\(diagnostic.totalFixable)..." : "Sửa \(diagnostic.totalFixable) Lỗi Tự Động")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(diagnostic.isFixingAll ? Color.gray : Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(diagnostic.isFixingAll)
                        .padding(.horizontal)
                        
                        if diagnostic.isFixingAll || !diagnostic.fixProgress.isEmpty {
                            Text(diagnostic.fixProgress)
                                .font(.caption)
                                .foregroundColor(.orange)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                }
                
                // ====== KẾT QUẢ QUÉT ======
                if diagnostic.isScanComplete {
                    // Hiển thị lỗi trước, rồi cảnh báo, rồi tốt
                    let sortedResults = diagnostic.results.sorted { statusOrder($0.status) < statusOrder($1.status) }
                    
                    ForEach(sortedResults) { item in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: item.icon)
                                .font(.title2)
                                .foregroundColor(colorForStatus(item.status))
                                .frame(width: 35)
                            
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(item.name)
                                        .font(.subheadline).bold()
                                    Spacer()
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(colorForStatus(item.status))
                                            .frame(width: 8, height: 8)
                                        Text(statusLabel(item.status))
                                            .font(.caption2)
                                            .foregroundColor(colorForStatus(item.status))
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(colorForStatus(item.status).opacity(0.15))
                                    .cornerRadius(8)
                                }
                                
                                Text(item.detail)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                if item.canAutoFix && item.status != .good {
                                    HStack(spacing: 4) {
                                        Image(systemName: "wrench.fill").font(.caption2)
                                        Text(item.fixAction)
                                            .font(.caption2)
                                    }
                                    .foregroundColor(.blue)
                                    .padding(.top, 2)
                                }
                                
                                if !item.canAutoFix && item.status != .good && !item.fixAction.isEmpty {
                                    HStack(spacing: 4) {
                                        Image(systemName: "hand.point.right.fill").font(.caption2)
                                        Text(item.fixAction)
                                            .font(.caption2)
                                    }
                                    .foregroundColor(.purple)
                                    .padding(.top, 2)
                                }
                            }
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
                
                Spacer().frame(height: 30)
            }
            .padding(.top)
        }
        .navigationTitle("Chẩn Đoán & Sửa Lỗi")
    }
    
    // ====== HELPERS ======
    
    func statBadge(count: Int, label: String, color: Color) -> some View {
        VStack {
            Text("\(count)")
                .font(.title2).bold()
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(width: 70)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
    
    func colorForScore(_ score: Int) -> Color {
        if score >= 80 { return .green }
        if score >= 50 { return .orange }
        return .red
    }
    
    func healthLabel(_ score: Int) -> String {
        if score >= 90 { return "Máy rất khoẻ mạnh!" }
        if score >= 70 { return "Máy hoạt động ổn định" }
        if score >= 50 { return "Máy có một số vấn đề" }
        return "Máy cần sửa chữa NGAY!"
    }
    
    func colorForStatus(_ status: DiagnosticStatus) -> Color {
        switch status {
        case .good, .fixed: return .green
        case .warning: return .orange
        case .critical: return .red
        case .fixing: return .blue
        }
    }
    
    func statusLabel(_ status: DiagnosticStatus) -> String {
        switch status {
        case .good: return "Tốt"
        case .warning: return "Cảnh báo"
        case .critical: return "Lỗi"
        case .fixing: return "Đang sửa"
        case .fixed: return "Đã sửa"
        }
    }
    
    func statusOrder(_ status: DiagnosticStatus) -> Int {
        switch status {
        case .critical: return 0
        case .warning: return 1
        case .fixing: return 2
        case .good: return 3
        case .fixed: return 4
        }
    }
}
