import CoreLocation
import MapKit
import SwiftUI

struct PassengerLiveMap: View {
    let driverLocation: DriverLocation?
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    var savedPickup: MorningPickup?
    var cameraPosition: Binding<MapCameraPosition>?
    var isActive: Bool = true

    @State private var internalPosition: MapCameraPosition = MapDefaults.homeMapPosition

    private var activePosition: Binding<MapCameraPosition> {
        cameraPosition ?? $internalPosition
    }

    private var displayPickup: CLLocationCoordinate2D? {
        selectedCoordinate ?? savedPickup?.coordinate
    }

    private var annotationSignature: String {
        let driver = driverLocation.map { "\($0.latitude),\($0.longitude)" } ?? "-"
        let pickup = displayPickup.map { "\($0.latitude),\($0.longitude)" } ?? "-"
        return "\(driver)|\(pickup)"
    }

    var body: some View {
        MapReader { proxy in
            Map(position: activePosition) {
                if let driverLocation {
                    Annotation(driverLocation.driverName, coordinate: driverLocation.coordinate) {
                        driverMarker
                    }
                }

                if let coordinate = displayPickup {
                    Annotation("Biniş noktası", coordinate: coordinate) {
                        pickupMarker
                    }
                }
            }
            .mapStyle(.hybrid(elevation: .realistic))
            .onTapGesture { location in
                guard let coordinate = proxy.convert(location, from: .local) else { return }
                selectedCoordinate = coordinate
                fitAllAnnotations(animated: true)
            }
        }
        .onAppear {
            fitAllAnnotations(animated: false)
            scheduleAnnotationRefresh()
        }
        .onChange(of: isActive) { _, active in
            guard active else { return }
            fitAllAnnotations(animated: false)
            scheduleAnnotationRefresh()
        }
        .onChange(of: annotationSignature) { _, _ in
            fitAllAnnotations(animated: false)
            scheduleAnnotationRefresh()
        }
    }

    private var driverMarker: some View {
        ZStack {
            Circle()
                .fill(NeonTheme.secondary.opacity(0.15))
                .frame(width: 56, height: 56)
            Circle()
                .stroke(NeonTheme.secondary.opacity(0.25), lineWidth: 1)
                .frame(width: 56, height: 56)
            Image(systemName: "location.north.fill")
                .font(.system(size: 28))
                .foregroundStyle(NeonTheme.secondary)
                .shadow(color: NeonTheme.secondary.opacity(0.8), radius: 8)
        }
    }

    private var pickupMarker: some View {
        VStack(spacing: 2) {
            Image(systemName: "mappin.circle.fill")
                .font(.title2)
                .foregroundStyle(NeonTheme.primary)
                .shadow(color: NeonTheme.primary.opacity(0.6), radius: 6)
            Text("Biniş")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(NeonTheme.onSurface)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(NeonTheme.surfaceContainer.opacity(0.9), in: Capsule())
        }
    }

    func fitCamera() {
        fitAllAnnotations(animated: true)
    }

    func zoom(by factor: Double) {
        guard var region = activePosition.wrappedValue.region else { return }
        region.span.latitudeDelta = min(0.5, max(0.005, region.span.latitudeDelta * factor))
        region.span.longitudeDelta = min(0.5, max(0.005, region.span.longitudeDelta * factor))
        withAnimation { activePosition.wrappedValue = .region(region) }
    }

    private func fitAllAnnotations(animated: Bool) {
        var coordinates: [CLLocationCoordinate2D] = []
        if let pickup = displayPickup { coordinates.append(pickup) }
        if let driver = driverLocation?.coordinate { coordinates.append(driver) }

        let region: MKCoordinateRegion
        if coordinates.isEmpty {
            region = MapDefaults.homeRegion
        } else {
            region = makeRegion(containing: coordinates)
        }

        applyRegion(region, animated: animated)
    }

    private func makeRegion(containing coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard let first = coordinates.first else { return MapDefaults.homeRegion }

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
                latitudeDelta: max(0.015, (maxLat - minLat) * 1.6),
                longitudeDelta: max(0.015, (maxLng - minLng) * 1.6)
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

    /// MapKit bazen annotation'ları kamera hareket edene kadar çizmez.
    private func scheduleAnnotationRefresh() {
        Task { @MainActor in
            let target = fittedRegionForAnnotations()
            applyRegion(target, animated: false)
            try? await Task.sleep(for: .milliseconds(120))

            activePosition.wrappedValue = .automatic
            try? await Task.sleep(for: .milliseconds(150))

            applyRegion(target, animated: false)
            try? await Task.sleep(for: .milliseconds(50))
            nudgeCameraToRefreshAnnotations()
            try? await Task.sleep(for: .milliseconds(50))
            applyRegion(target, animated: false)
        }
    }

    private func fittedRegionForAnnotations() -> MKCoordinateRegion {
        var coordinates: [CLLocationCoordinate2D] = []
        if let pickup = displayPickup { coordinates.append(pickup) }
        if let driver = driverLocation?.coordinate { coordinates.append(driver) }
        return coordinates.isEmpty ? MapDefaults.homeRegion : makeRegion(containing: coordinates)
    }

    private func nudgeCameraToRefreshAnnotations() {
        guard var region = activePosition.wrappedValue.region else { return }
        region.center.latitude += 0.00008
        region.center.longitude += 0.00008
        activePosition.wrappedValue = .region(region)
    }
}

#Preview {
    PassengerLiveMap(
        driverLocation: DriverLocation(
            latitude: MapDefaults.homeCoordinate.latitude,
            longitude: MapDefaults.homeCoordinate.longitude,
            updatedAt: Date(),
            isActive: true,
            driverName: "Ahmet"
        ),
        selectedCoordinate: .constant(nil),
        savedPickup: nil
    )
}
