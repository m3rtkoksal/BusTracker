import CoreLocation
import Foundation

/// Firestore konumu (aktif servis) yoksa sürücü haritasında cihaz konumunu göster.
func resolveDriverMapLocation(
    firestoreLocation: DriverLocation?,
    deviceLocation: CLLocation?,
    driverName: String
) -> DriverLocation? {
    if let firestoreLocation {
        return firestoreLocation
    }
    guard let deviceLocation else { return nil }
    return DriverLocation(
        latitude: deviceLocation.coordinate.latitude,
        longitude: deviceLocation.coordinate.longitude,
        updatedAt: deviceLocation.timestamp,
        isActive: false,
        driverName: driverName
    )
}
