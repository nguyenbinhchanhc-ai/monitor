import SwiftUI

struct FileExplorerView: View {
    @State private var inputPath: String = "/System/Library/CoreServices/SystemVersion.plist"
    @State private var fileContent: String = ""
    @State private var errorMessage: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Cơ chế bảo mật Apple Sandbox")
                .font(.headline)
                .padding(.top)
            
            Text("Ứng dụng này sẽ cố gắng đọc các file hệ thống để bạn tự mình kiểm chứng việc Apple ngăn chặn quyền truy cập như thế nào.")
                .font(.footnote)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            TextField("Nhập đường dẫn (vd: /etc/passwd hoặc /)", text: $inputPath)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .disableAutocorrection(true)
                .autocapitalization(.none)
                .padding(.horizontal)
            
            Button(action: readFile) {
                Text("Thử Đọc File / Thư Mục")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
            }
            
            ScrollView {
                VStack(alignment: .leading) {
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding()
                    } else {
                        Text(fileContent)
                            .font(.system(.caption, design: .monospaced))
                            .padding()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(10)
            .padding()
        }
        .navigationTitle("Khám Phá File")
    }
    
    func readFile() {
        errorMessage = ""
        fileContent = ""
        
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        
        if fileManager.fileExists(atPath: inputPath, isDirectory: &isDir) {
            if isDir.boolValue {
                do {
                    let contents = try fileManager.contentsOfDirectory(atPath: inputPath)
                    fileContent = "THƯ MỤC CHỨA CÁC FILE & THƯ MỤC CON:\n\n" + contents.joined(separator: "\n")
                } catch {
                    errorMessage = " LỖI BẢO MẬT: Sandbox từ chối quyền truy cập thư mục này!\n\nChi tiết: \(error.localizedDescription)"
                }
            } else {
                do {
                    let text = try String(contentsOfFile: inputPath, encoding: .utf8)
                    fileContent = "NỘI DUNG VĂN BẢN:\n\n" + text
                } catch {
                    if let data = fileManager.contents(atPath: inputPath) {
                        fileContent = "DỮ LIỆU NHỊ PHÂN (Binary Data)\nKích thước: \(data.count) bytes\n\n(Không thể hiển thị dưới dạng văn bản Text)"
                    } else {
                        errorMessage = " LỖI BẢO MẬT: Apple Sandbox đã chặn quyền đọc file này!\n\nChi tiết: \(error.localizedDescription)"
                    }
                }
            }
        } else {
            errorMessage = " LỖI 404: Không tìm thấy file hoặc đường dẫn không tồn tại trên hệ thống."
        }
    }
}
