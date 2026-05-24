import MapKit
import SwiftUI

struct ShuttleMapView: View {
    let driverLocation: DriverLocation?
    var morningPickups: [MorningPickup] = []
    var mapStyle: MapStyle = .standard(elevation: .realistic)
    var cameraPosition: Binding<MapCameraPosition>?

    @State private var internalPosition: MapCameraPosition = MapDefaults.homeMapPosition

    private var activePosition: Binding<MapCameraPosition> {
        cameraPosition ?? $internalPosition
    }

    var body: some View {
        Map(position: activePosition) {
            if let driverLocation {
                Annotation(driverLocation.driverName, coordinate: driverLocation.coordinate) {
                    driverMarker
                }
            }

            ForEach(morningPickups) { pickup in
                Annotation(pickup.name, coordinate: pickup.coordinate) {
                    pickupMarker(for: pickup)
                }
            }
        }
        .mapStyle(mapStyle)
        .onAppear { fitCamera(animated: false) }
        .onChange(of: driverLocation?.updatedAt) { _, _ in fitCamera() }
        .onChange(of: morningPickups.count) { _, _ in fitCamera() }
    }

    private var driverMarker: some View {
        ZStack {
            Circle()
                .fill(NeonTheme.secondary.opacity(0.15))
                .frame(width: 56, height: 56)
            Image(systemName: "location.north.fill")
                .font(.system(size: 28))
                .foregroundStyle(NeonTheme.secondary)
                .shadow(color: NeonTheme.secondary.opacity(0.8), radius: 8)
        }
    }

    private func pickupMarker(for pickup: MorningPickup) -> some View {
        VStack(spacing: 2) {
            Image(systemName: "mappin.circle.fill")
                .font(.title2)
                .foregroundStyle(NeonTheme.primary)
                .shadow(color: NeonTheme.primary.opacity(0.6), radius: 6)
            Text(pickup.name)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(NeonTheme.onSurface)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(NeonTheme.surfaceContainer.opacity(0.9), in: Capsule())
        }
    }

    func fitCamera(animated: Bool = true) {
        var coordinates: [CLLocationCoordinate2D] = morningPickups.map(\.coordinate)
        if let driverLocation {
            coordinates.append(driverLocation.coordinate)
        }

        guard let first = coordinates.first else {
            activePosition.wrappedValue = .region(MapDefaults.homeRegion)
            return
        }

        let region: MKCoordinateRegion
        if coordinates.count == 1 {
            region = MKCoordinateRegion(
                center: first,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        } else {
            var minLat = first.latitude
            var maxLat = first.latitude
            var minLng = first.longitude
            var maxLng = first.longitude

            for coordinate in coordinates {
                minLat = min(minLat, coordinate.latitude)
                maxLat = max(maxLat, coordinate.latitude)
                minLng = min(minLng, coordinate.longitude)
                maxLng = max(maxLng, coordinate.longitude)
            }

            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: (minLat + maxLat) / 2,
                    longitude: (minLng + maxLng) / 2
                ),
                span: MKCoordinateSpan(
                    latitudeDelta: max(0.02, (maxLat - minLat) * 1.4),
                    longitudeDelta: max(0.02, (maxLng - minLng) * 1.4)
                )
            )
        }

        if animated {
            withAnimation { activePosition.wrappedValue = .region(region) }
        } else {
            activePosition.wrappedValue = .region(region)
        }
    }

    func zoom(by factor: Double) {
        guard var region = activePosition.wrappedValue.region else { return }
        region.span.latitudeDelta = min(0.5, max(0.005, region.span.latitudeDelta * factor))
        region.span.longitudeDelta = min(0.5, max(0.005, region.span.longitudeDelta * factor))
        withAnimation { activePosition.wrappedValue = .region(region) }
    }
}

#Preview {
    ShuttleMapView(
        driverLocation: DriverLocation(
            latitude: MapDefaults.homeCoordinate.latitude,
            longitude: MapDefaults.homeCoordinate.longitude,
            updatedAt: Date(),
            isActive: true,
            driverName: "Ahmet"
        ),
        morningPickups: [
            MorningPickup(memberID: "1", name: "Ayşe", latitude: 41.01, longitude: 28.98, updatedAt: Date())
        ],
        mapStyle: .hybrid(elevation: .realistic)
    )
}
