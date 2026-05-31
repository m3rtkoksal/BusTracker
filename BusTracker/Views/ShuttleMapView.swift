import MapKit
import SwiftUI

struct ShuttleMapView: View {
    let driverLocation: DriverLocation?
    var driverRoute: [CLLocationCoordinate2D] = []
    var isTripActive: Bool = false
    var morningPickups: [MorningPickup] = []
    var mapStyle: MapStyle = .standard(elevation: .flat)
    var cameraPosition: Binding<MapCameraPosition>?
    /// Konum/pin güncellenince tüm pinlere zoom yapılmasın (sürücü haritası).
    var autoFitCameraOnUpdate: Bool = false
    /// Üst view konum/pin hazır olunca artırır; MapKit annotation yenilemesi tetiklenir.
    var annotationRefreshNonce: Int = 0

    @State private var internalPosition: MapCameraPosition = MapDefaults.homeMapPosition

    private var activePosition: Binding<MapCameraPosition> {
        cameraPosition ?? $internalPosition
    }

    private var annotationSignature: String {
        let driver = driverLocation.map { "\($0.latitude),\($0.longitude),\($0.updatedAt.timeIntervalSince1970)" } ?? "-"
        let pickups = morningPickups
            .map { "\($0.memberID):\($0.latitude),\($0.longitude)" }
            .joined(separator: ";")
        return "\(driver)|\(pickups)"
    }

    var body: some View {
        Map(position: activePosition) {
            if DriverRouteDisplay.shouldDrawPolyline(
                route: driverRoute,
                driverLocation: driverLocation,
                isTripActive: isTripActive
            ) {
                MapPolyline(
                    coordinates: DriverRouteDisplay.polylineCoordinates(
                        route: driverRoute,
                        driverLocation: driverLocation,
                        isTripActive: isTripActive
                    )
                )
                .stroke(NeonTheme.secondary.opacity(0.75), lineWidth: 4)
            }

            if let driverLocation {
                Annotation(driverLocation.driverName, coordinate: driverLocation.coordinate) {
                    driverMarker
                }
            }

            ForEach(morningPickups) { pickup in
                Annotation("", coordinate: pickup.coordinate) {
                    pickupMarker(for: pickup)
                }
            }
        }
        .mapStyle(mapStyle)
        .onAppear {
            if autoFitCameraOnUpdate {
                fitCamera(animated: false)
            }
            scheduleAnnotationRefresh()
        }
        .onChange(of: annotationSignature) { _, _ in
            if autoFitCameraOnUpdate {
                fitCamera(animated: false)
            }
            scheduleAnnotationRefresh()
        }
        .onChange(of: annotationRefreshNonce) { _, _ in
            scheduleAnnotationRefresh()
        }
    }

    private var driverMarker: some View {
        ZStack {
            Circle()
                .fill(NeonTheme.mapDriverPin.opacity(0.15))
                .frame(width: 56, height: 56)
            Image(systemName: "location.north.fill")
                .font(.system(size: 28))
                .foregroundStyle(NeonTheme.mapDriverPin)
                .shadow(color: NeonTheme.mapDriverPin.opacity(0.8), radius: 8)
        }
    }

    private func pickupMarker(for pickup: MorningPickup) -> some View {
        VStack(spacing: 2) {
            Image(systemName: "mappin.circle.fill")
                .font(.title2)
                .foregroundStyle(NeonTheme.mapPickupPin)
                .shadow(color: NeonTheme.mapPickupPin.opacity(0.6), radius: 6)
            Text(pickup.name)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(NeonTheme.onSurface)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(NeonTheme.surfaceContainer.opacity(0.9), in: Capsule())
        }
    }

    func fitCamera(animated: Bool = true) {
        let region = fittedRegion()
        applyRegion(region, animated: animated)
    }

    private func fittedRegion() -> MKCoordinateRegion {
        var coordinates: [CLLocationCoordinate2D] = morningPickups.map(\.coordinate)
        if let driverLocation {
            coordinates.append(driverLocation.coordinate)
        }

        guard let first = coordinates.first else {
            return MapDefaults.homeRegion
        }

        if coordinates.count == 1 {
            return MKCoordinateRegion(
                center: first,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        }

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

        return MKCoordinateRegion(
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

    private func applyRegion(_ region: MKCoordinateRegion, animated: Bool) {
        if animated {
            withAnimation { activePosition.wrappedValue = .region(region) }
        } else {
            activePosition.wrappedValue = .region(region)
        }
    }

    /// MapKit bazen annotation'ları kamera hareket edene kadar çizmez; mevcut zoom'u koruyarak yeniler.
    private func scheduleAnnotationRefresh() {
        Task { @MainActor in
            let target = autoFitCameraOnUpdate ? fittedRegion() : resolvedRegionForRefresh()
            await runAnnotationRefreshCycle(preserving: target)
        }
    }

    private func resolvedRegionForRefresh() -> MKCoordinateRegion {
        if let region = activePosition.wrappedValue.region {
            return region
        }
        if let driverLocation {
            return MKCoordinateRegion(
                center: driverLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        }
        if let pickup = morningPickups.first {
            return MKCoordinateRegion(
                center: pickup.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        }
        return MapDefaults.homeRegion
    }

    private func runAnnotationRefreshCycle(preserving target: MKCoordinateRegion) async {
        applyRegion(target, animated: false)
        try? await Task.sleep(for: .milliseconds(100))

        activePosition.wrappedValue = .automatic
        try? await Task.sleep(for: .milliseconds(160))

        applyRegion(target, animated: false)
        try? await Task.sleep(for: .milliseconds(50))

        var nudged = target
        nudged.center.latitude += 0.00006
        nudged.center.longitude += 0.00006
        applyRegion(nudged, animated: false)
        try? await Task.sleep(for: .milliseconds(50))

        applyRegion(target, animated: false)
    }

    func zoom(by factor: Double) {
        guard var region = activePosition.wrappedValue.region else { return }
        region.span.latitudeDelta = min(0.5, max(0.005, region.span.latitudeDelta * factor))
        region.span.longitudeDelta = min(0.5, max(0.005, region.span.longitudeDelta * factor))
        withAnimation { activePosition.wrappedValue = .region(region) }
    }
}

enum DriverRouteDisplay {
    static func polylineCoordinates(
        route: [CLLocationCoordinate2D],
        driverLocation: DriverLocation?,
        isTripActive: Bool
    ) -> [CLLocationCoordinate2D] {
        guard isTripActive, let live = driverLocation?.coordinate else {
            return route
        }
        if route.isEmpty {
            return [live, live]
        }
        return route + [live]
    }

    static func shouldDrawPolyline(
        route: [CLLocationCoordinate2D],
        driverLocation: DriverLocation?,
        isTripActive: Bool
    ) -> Bool {
        guard isTripActive else { return false }
        return driverLocation != nil || !route.isEmpty
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
        mapStyle: .hybrid(elevation: .flat)
    )
}
