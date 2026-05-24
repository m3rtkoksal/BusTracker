import Foundation
import CoreLocation

struct DriverLocation: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    let updatedAt: Date
    let isActive: Bool
    let driverName: String

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
