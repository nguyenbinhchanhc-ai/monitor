import Foundation
import CoreLocation

class BackgroundKeepAlive: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = BackgroundKeepAlive()
    
    private var locationManager: CLLocationManager?
    @Published var isBackgroundEnabled = false
    @Published var status: String = "Chưa kích hoạt"
    
    override init() {
        super.init()
        // KHÔNG tạo CLLocationManager trong init() - chờ user bật
    }
    
    func startBackground() {
        if locationManager == nil {
            let mgr = CLLocationManager()
            mgr.delegate = self
            mgr.desiredAccuracy = kCLLocationAccuracyThreeKilometers
            mgr.distanceFilter = 99999
            mgr.pausesLocationUpdatesAutomatically = false
            locationManager = mgr
        }
        
        locationManager?.requestAlwaysAuthorization()
    }
    
    func stopBackground() {
        locationManager?.stopMonitoringSignificantLocationChanges()
        locationManager?.stopUpdatingLocation()
        isBackgroundEnabled = false
        status = "Đã tắt chạy ngầm"
    }
    
    private func beginTracking() {
        guard let mgr = locationManager else { return }
        
        // Dùng significantLocationChanges - KHÔNG cần allowsBackgroundLocationUpdates
        // Hoạt động tốt với sideload app, hao pin rất ít
        mgr.startMonitoringSignificantLocationChanges()
        isBackgroundEnabled = true
        status = "Đang chạy ngầm (Significant Location) ✅"
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Không làm gì - chỉ giữ app sống
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let authStatus: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            authStatus = manager.authorizationStatus
        } else {
            authStatus = CLLocationManager.authorizationStatus()
        }
        
        switch authStatus {
        case .authorizedAlways:
            status = "Quyền: Luôn luôn ✅"
            beginTracking()
        case .authorizedWhenInUse:
            status = "Quyền: Khi dùng app ⚠️ - Vào Cài đặt → chọn 'Luôn luôn'"
            // Vẫn chạy được khi app foreground
            beginTracking()
        case .denied, .restricted:
            status = "Quyền: Bị từ chối ❌"
            isBackgroundEnabled = false
        case .notDetermined:
            status = "Đang chờ cấp quyền..."
        @unknown default:
            status = "Không xác định"
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Bỏ qua - app vẫn sống
    }
}
