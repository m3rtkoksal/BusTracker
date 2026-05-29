import CoreLocation
import Foundation

#if canImport(UIKit)
import UIKit
#endif

@MainActor
@Observable
final class LocationTracker: NSObject {
    var currentLocation: CLLocation?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var errorMessage: String?

    var onLocationUpdate: ((CLLocation) -> Void)?

    /// Sürücü: yalnızca "Her zaman" ile arka plan paylaşımı.
    var needsAlwaysAuthorization: Bool {
        authorizationStatus == .authorizedWhenInUse
    }

    var hasWhenInUseAuthorization: Bool {
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        default:
            return false
        }
    }

    /// Her kontrol öncesi canlı okunur (izin penceresi kapandıktan hemen sonra güncellenir).
    var canDriverStartTrip: Bool {
        let live = manager.authorizationStatus
        if authorizationStatus != live {
            authorizationStatus = live
        }
        return live == .authorizedAlways
    }

    /// Sistem izin penceresi kapandıktan sonra kısa süre gecikme olabilir.
    func waitForDriverAlwaysAuthorization(maxWaitSeconds: Double = 2.0) async -> Bool {
        let steps = Int(maxWaitSeconds * 10)
        for _ in 0..<steps {
            refreshAuthorizationStatus()
            if canDriverStartTrip { return true }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        refreshAuthorizationStatus()
        return canDriverStartTrip
    }

    private let manager = CLLocationManager()
    private var isTracking = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10
        manager.activityType = .automotiveNavigation
        manager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = manager.authorizationStatus
        #if targetEnvironment(simulator)
        currentLocation = MapDefaults.homeLocation
        #endif
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = manager.authorizationStatus
    }

    /// Giriş / kayıt sonrası tüm kullanıcılar: "Uygulama kullanılırken".
    func requestWhenInUsePermissionIfNeeded() {
        refreshAuthorizationStatus()
        if authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    /// Sürücü sefer başlatma: "Her zaman" izni.
    func requestDriverAlwaysPermissionIfNeeded() {
        refreshAuthorizationStatus()
        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        default:
            break
        }
    }

    /// Yolcu haritası: yalnızca when-in-use + tek konum.
    func requestPassengerSingleLocation() {
        refreshAuthorizationStatus()
        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    /// Sürücü haritası (servis öncesi): cihaz konumunu haritada göstermek için tek okuma.
    func requestDriverSingleLocation() {
        refreshAuthorizationStatus()
        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    func openAppSettings() {
#if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
#endif
    }

    func startTracking() {
        #if targetEnvironment(simulator)
        isTracking = true
        deliverLocation(MapDefaults.simulatorPinnedLocation)
        return
        #endif

        refreshAuthorizationStatus()
        guard authorizationStatus == .authorizedAlways else {
            requestDriverAlwaysPermissionIfNeeded()
            return
        }

        isTracking = true
        applyBackgroundSettingsIfNeeded()
        manager.startUpdatingLocation()
    }

    var effectiveLocation: CLLocation? {
        #if targetEnvironment(simulator)
        MapDefaults.simulatorPinnedLocation
        #else
        currentLocation
        #endif
    }

    func stopTracking() {
        isTracking = false
        onLocationUpdate = nil
        manager.stopUpdatingLocation()
#if os(iOS)
        manager.allowsBackgroundLocationUpdates = false
#endif
    }

    private func deliverLocation(_ location: CLLocation) {
        #if targetEnvironment(simulator)
        let resolved = MapDefaults.simulatorPinnedLocation
        currentLocation = resolved
        onLocationUpdate?(resolved)
        #else
        currentLocation = location
        onLocationUpdate?(location)
        #endif
    }

    private func applyBackgroundSettingsIfNeeded() {
#if os(iOS)
        guard authorizationStatus == .authorizedAlways else { return }
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
#endif
    }
}

extension LocationTracker: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            if isTracking, authorizationStatus == .authorizedAlways {
                applyBackgroundSettingsIfNeeded()
                manager.startUpdatingLocation()
            } else if hasWhenInUseAuthorization {
                manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            deliverLocation(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            errorMessage = error.localizedDescription
        }
    }
}
