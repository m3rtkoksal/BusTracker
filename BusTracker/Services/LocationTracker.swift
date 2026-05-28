import CoreLocation
import Foundation

@MainActor
@Observable
final class LocationTracker: NSObject {
    var currentLocation: CLLocation?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var errorMessage: String?

    var onLocationUpdate: ((CLLocation) -> Void)?

    var needsAlwaysAuthorization: Bool {
        authorizationStatus == .authorizedWhenInUse
    }

    var isAuthorizedForTracking: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
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

    func setSimulatedLocation(_ location: CLLocation) {
        currentLocation = location
    }

    func requestPermission() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        default:
            break
        }
    }

    func requestBackgroundPermission() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestAlwaysAuthorization()
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        default:
            break
        }
    }

    func startTracking() {
        #if targetEnvironment(simulator)
        isTracking = true
        deliverLocation(MapDefaults.simulatorPinnedLocation)
        return
        #endif

        guard isAuthorizedForTracking else {
            requestBackgroundPermission()
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

    func stopTracking() {
        isTracking = false
        onLocationUpdate = nil
        manager.stopUpdatingLocation()
#if os(iOS)
        manager.allowsBackgroundLocationUpdates = false
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
            if isTracking, isAuthorizedForTracking {
                applyBackgroundSettingsIfNeeded()
                manager.startUpdatingLocation()
            } else if isAuthorizedForTracking {
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
