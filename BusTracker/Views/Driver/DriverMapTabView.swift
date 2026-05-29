import CoreLocation
import MapKit
import SwiftUI

struct DriverMapTabView: View {
    let driverLocation: DriverLocation?
    var driverRoute: [CLLocationCoordinate2D] = []
    let morningPickups: [MorningPickup]
    let stats: DriverPassengerStats
    let isTripActive: Bool

    @State private var mapPosition: MapCameraPosition = MapDefaults.homeMapPosition

    private var nextPickup: MorningPickup? {
        morningPickups.first
    }

    var body: some View {
        ZStack {
            ShuttleMapView(
                driverLocation: driverLocation,
                driverRoute: driverRoute,
                isTripActive: isTripActive,
                morningPickups: morningPickups,
                mapStyle: .hybrid(elevation: .realistic),
                cameraPosition: $mapPosition
            )
            .ignoresSafeArea()

            NeonMapOverlay()

            VStack(spacing: 0) {
                topOverlay
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                Spacer(minLength: 0)

                bentoGrid
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
        .onAppear {
            fitCamera()
        }
        .onChange(of: driverLocation?.updatedAt) { _, _ in
            fitCamera()
        }
        .onChange(of: morningPickups.map(\.memberID).joined()) { _, _ in
            fitCamera()
        }
    }

    private var topOverlay: some View {
        HStack(alignment: .top, spacing: 12) {
            nextStopCard

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 8) {
                if isTripActive {
                    activeBadge
                }
                mapControls
            }
        }
    }

    private var activeBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(NeonTheme.secondary)
                .frame(width: 8, height: 8)
                .shadow(color: NeonTheme.secondary.opacity(0.8), radius: 4)
            Text("AKTİF")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundStyle(NeonTheme.secondary)
                .shadow(color: NeonTheme.secondary.opacity(0.5), radius: 6)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(NeonTheme.surfaceContainerLow.opacity(0.9))
        .overlay {
            Rectangle()
                .strokeBorder(NeonTheme.secondary.opacity(0.2), lineWidth: 1)
        }
    }

    private var nextStopCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SONRAKİ DURAK")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .tracking(0.5)
                .foregroundStyle(NeonTheme.onSurfaceVariant)

            if let pickup = nextPickup {
                Text(pickup.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(NeonTheme.onSurface)

                HStack {
                    if let distanceText = distanceToPickup(pickup) {
                        Text(distanceText)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(NeonTheme.secondary)
                    }
                    Spacer()
                    Text("Sabah biniş")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(NeonTheme.onSurfaceVariant)
                }
            } else {
                Text("Durak yok")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(NeonTheme.onSurface)
                Text("Yolcu biniş noktası bekleniyor.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(NeonTheme.onSurfaceVariant)
            }
        }
        .padding(12)
        .frame(maxWidth: 200, alignment: .leading)
        .background(NeonTheme.surfaceContainer.opacity(0.85))
        .background(.ultraThinMaterial.opacity(0.2))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(NeonTheme.secondary)
                .frame(width: 4)
        }
        .overlay {
            Rectangle()
                .strokeBorder(NeonTheme.secondary.opacity(0.3), lineWidth: 1)
        }
        .shadow(color: NeonTheme.secondary.opacity(0.08), radius: 8)
    }

    private var mapControls: some View {
        VStack(spacing: 8) {
            mapControlButton(icon: "plus") { zoom(by: 0.7) }
            mapControlButton(icon: "minus") { zoom(by: 1.35) }
            mapControlButton(icon: "location.fill", highlighted: true) { fitCamera() }
        }
    }

    private func mapControlButton(icon: String, highlighted: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(highlighted ? NeonTheme.secondary : NeonTheme.onSurface)
                .frame(width: 40, height: 40)
                .background(NeonTheme.surfaceContainer.opacity(0.9))
                .overlay {
                    Rectangle()
                        .strokeBorder(
                            highlighted ? NeonTheme.secondary.opacity(0.5) : NeonTheme.outline.opacity(0.3),
                            lineWidth: 1
                        )
                }
                .shadow(color: highlighted ? NeonTheme.secondary.opacity(0.2) : .clear, radius: 6)
        }
        .buttonStyle(.plain)
    }

    private var bentoGrid: some View {
        HStack(spacing: 8) {
            bentoCard(
                title: "KAPASİTE",
                value: "\(stats.capacityOccupied)",
                suffix: "/ \(stats.total)",
                valueColor: NeonTheme.primary,
                footnote: stats.unknown > 0 ? "\(stats.unknown) belirtmedi" : nil
            )
            bentoCard(
                title: "DURAKLAR",
                value: "\(morningPickups.count)",
                suffix: nil,
                valueColor: NeonTheme.onSurface,
                footnote: isTripActive ? nil : "Servis bekliyor",
                footnoteIcon: isTripActive ? nil : "clock"
            )
        }
    }

    private func bentoCard(
        title: String,
        value: String,
        suffix: String?,
        valueColor: Color,
        footnote: String? = nil,
        footnoteIcon: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(NeonTheme.onSurfaceVariant)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(valueColor)
                    .shadow(color: valueColor == NeonTheme.primary ? NeonTheme.primary.opacity(0.5) : .clear, radius: 6)
                if let suffix {
                    Text(suffix)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(NeonTheme.onSurfaceVariant)
                }
            }

            if let footnote {
                HStack(spacing: 4) {
                    if let footnoteIcon {
                        Image(systemName: footnoteIcon)
                            .font(.caption)
                            .foregroundStyle(Color(hex: 0xFFE04A))
                    }
                    Text(footnote)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(NeonTheme.onSurface)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 96, maxHeight: 96, alignment: .topLeading)
        .background(NeonTheme.surfaceContainer.opacity(0.9))
        .background(.ultraThinMaterial.opacity(0.15))
        .overlay {
            Rectangle()
                .strokeBorder(NeonTheme.outline.opacity(0.2), lineWidth: 1)
        }
    }

    private func distanceToPickup(_ pickup: MorningPickup) -> String? {
        guard let driverLocation else { return nil }
        let driver = CLLocation(latitude: driverLocation.latitude, longitude: driverLocation.longitude)
        let stop = CLLocation(latitude: pickup.latitude, longitude: pickup.longitude)
        let meters = driver.distance(from: stop)
        if meters >= 1000 {
            return String(format: "%.1f KM", meters / 1000)
        }
        return String(format: "%.0f M", meters)
    }

    private func zoom(by factor: Double) {
        guard var region = mapPosition.region else { return }
        region.span.latitudeDelta = min(0.5, max(0.005, region.span.latitudeDelta * factor))
        region.span.longitudeDelta = min(0.5, max(0.005, region.span.longitudeDelta * factor))
        withAnimation { mapPosition = .region(region) }
    }

    private func fitCamera() {
        var coordinates: [CLLocationCoordinate2D] = morningPickups.map(\.coordinate)
        if let driverLocation {
            coordinates.append(driverLocation.coordinate)
        }

        guard let first = coordinates.first else {
            mapPosition = .region(MapDefaults.homeRegion)
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

        withAnimation { mapPosition = .region(region) }
    }
}
