import SwiftUI

struct SecurityScannerView: View {
    @StateObject private var scanner = SecurityScannerManager()
    
    var body: some View {
        VStack {
            Text("Trình Phân Tích Quyền Hạn")
                .font(.headline)
                .padding(.top)
            
            Text("Công cụ này tự động quét các giới hạn bảo mật Sandbox để bạn thấy rõ ứng dụng đang được Apple cấp quyền can thiệp vào những gì.")
                .font(.footnote)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                scanner.runScan()
            }) {
                Text(scanner.isScanning ? "Đang quét sâu hệ thống..." : "Bắt Đầu Quét Hệ Thống")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(scanner.isScanning ? Color.gray : Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
            }
            .disabled(scanner.isScanning)
            
            ScrollView {
                if scanner.isScanning {
                    ProgressView()
                        .padding(.top, 50)
                } else if let report = scanner.report {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // Status Section
                        VStack(alignment: .leading, spacing: 10) {
                            Text("TRẠNG THÁI BẢO MẬT").font(.subheadline).bold().foregroundColor(.gray)
                            
                            HStack {
                                Text("Quyền tối cao (Root):")
                                Spacer()
                                Text(report.isRoot ? "CÓ" : "KHÔNG")
                                    .bold()
                                    .foregroundColor(report.isRoot ? .red : .green)
                            }
                            
                            HStack {
                                Text("Hàng rào Hộp cát (Sandbox):")
                                Spacer()
                                Text(report.isSandboxed ? "BỊ KHOÁ CHẶT" : "ĐÃ VƯỢT RÀO")
                                    .bold()
                                    .foregroundColor(report.isSandboxed ? .green : .red)
                            }
                            
                            HStack {
                                Text("Dấu vết Jailbreak/TrollStore:")
                                Spacer()
                                Text(report.isJailbroken ? "PHÁT HIỆN" : "KHÔNG")
                                    .bold()
                                    .foregroundColor(report.isJailbroken ? .red : .green)
                            }
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                        
                        // Allowed Section
                        VStack(alignment: .leading, spacing: 10) {
                            Text("QUYỀN ĐƯỢC PHÉP CAN THIỆP (ALLOWED)").font(.subheadline).bold().foregroundColor(.green)
                            ForEach(report.allowedPermissions, id: \.self) { perm in
                                HStack(alignment: .top) {
                                    Image(systemName: "checkmark.shield.fill").foregroundColor(.green)
                                    Text(perm)
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                        
                        // Blocked Section
                        VStack(alignment: .leading, spacing: 10) {
                            Text("BỊ APPLE CẤM CAN THIỆP (BLOCKED)").font(.subheadline).bold().foregroundColor(.red)
                            ForEach(report.blockedPermissions, id: \.self) { perm in
                                HStack(alignment: .top) {
                                    Image(systemName: "xmark.shield.fill").foregroundColor(.red)
                                    Text(perm)
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                    }
                    .padding()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Đặc Quyền")
    }
}
