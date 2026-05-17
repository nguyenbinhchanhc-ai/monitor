import Foundation
import CoreLocation

class BackgroundKeepAlive: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = BackgroundKeepAlive()
    
    private let locationManager = CLLocationManager()
    @Published var isBackgroundEnabled = false
    @Published var status: String = "Chưa kích hoạt"
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers // Tiết kiệm pin nhất
        locationManager.distanceFilter = 99999 // Hầu như không bao giờ cập nhật vị trí thật
    }
    
    func startBackground() {
        locationManager.requestAlwaysAuthorization()
        locationManager.startUpdatingLocation()
        isBackgroundEnabled = true
        status = "Đang chạy ngầm (Location)"
    }
    
    func stopBackground() {
        locationManager.stopUpdatingLocation()
        isBackgroundEnabled = false
        status = "Đã tắt chạy ngầm"
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Không làm gì cả - chỉ cần giữ app sống
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways:
            self.status = "Quyền: Luôn luôn ✅ - App sẽ chạy ngầm"
        case .authorizedWhenInUse:
            self.status = "Quyền: Khi dùng app ⚠️ - Hãy chọn 'Luôn luôn' trong Cài đặt"
        case .denied, .restricted:
            self.status = "Quyền: Bị từ chối ❌ - App sẽ bị iOS tắt khi chạy ngầm"
            isBackgroundEnabled = false
        case .notDetermined:
            self.status = "Đang chờ cấp quyền..."
        @unknown default:
            self.status = "Không xác định"
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Bỏ qua lỗi - app vẫn sống
    }
}
