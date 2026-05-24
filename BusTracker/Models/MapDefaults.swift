import CoreLocation
import _MapKit_SwiftUI
import MapKit

enum MapDefaults {
    /// Sancaktepe Atatürk mahallesi, 34785
    static let homeCoordinate = CLLocationCoordinate2D(latitude: 41.013298, longitude: 29.224813)

    static var homeRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: homeCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
        )
    }

    static var homeMapPosition: MapCameraPosition {
        .region(homeRegion)
    }

    static var homeLocation: CLLocation {
        CLLocation(latitude: homeCoordinate.latitude, longitude: homeCoordinate.longitude)
    }

    /// Rough bounds for Istanbul area dev checks.
    static func isNearHome(_ coordinate: CLLocationCoordinate2D) -> Bool {
        (36.0 ... 42.5).contains(coordinate.latitude)
            && (25.0 ... 45.0).contains(coordinate.longitude)
    }

    #if targetEnvironment(simulator)
    static var simulatorPinnedLocation: CLLocation { homeLocation }
    #endif
}
