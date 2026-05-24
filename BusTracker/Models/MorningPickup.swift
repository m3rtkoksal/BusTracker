import CoreLocation
import Foundation

struct MorningPickup: Identifiable, Equatable {
    let memberID: String
    let name: String
    let latitude: Double
    let longitude: Double
    let updatedAt: Date

    var id: String { memberID }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
