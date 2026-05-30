import MapKit
import SwiftUI

struct PassengerHomeView: BaseView {
    @Environment(ShuttleStore.self) private var store
    @Environment(UserSession.self) private var session
    @Environment(AuthService.self) private var authService
    @Environment(LocationTracker.self) private var locationTracker
    @State var viewModel = PassengerHomeViewModel()
    @State var tabBar = PassengerTabBarController()
    @State private var mapPosition: MapCameraPosition = MapDefaults.homeMapPosition
    @State private var showMyServices = false
    @State private var pendingCenterOnPassenger = false
    @State private var hasInitializedMapCamera = false
    @State private var mapSnapshotDriverLocation: DriverLocation?
    @State private var mapSnapshotDriverRoute: [CLLocationCoordinate2D] = []

    private var profile: UserProfile? { session.profile }

    private var myAttendance: AttendanceStatus {
        guard let memberID = profile?.memberID,
              let member = store.members.first(where: { $0.id == memberID })
        else { return .unknown }
        return member.attendance
    }

    private var savedMorningPickup: MorningPickup? {
        guard let memberID = profile?.memberID else { return nil }
        return store.morningPickup(for: memberID)
    }

    func content() -> some View {
        VStack(spacing: 0) {
            if tabBar.selectedTab != .map {
                passengerTopBar
            }

            ZStack {
                mapTab
                    .zIndex(0)
                    .allowsHitTesting(tabBar.selectedTab == .map)

                if tabBar.selectedTab == .service {
                    serviceTab
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(NeonTheme.background)
                        .zIndex(1)
                } else if tabBar.selectedTab == .settings {
                    settingsTab
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(NeonTheme.background)
                        .zIndex(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            PassengerTabBar(controller: tabBar)
        }
        .onAppear {
            viewModel.onAppear(store: store, session: session)
            viewModel.loadSavedPickup(from: store, session: session)
            viewModel.presentTripAttendanceSheetIfNeeded(
                isTripActive: store.isTripActive,
                attendance: myAttendance
            )
        }
        .onChange(of: tabBar.selectedTab) { oldTab, tab in
            if oldTab == .map {
                mapSnapshotDriverLocation = store.driverLocation
                mapSnapshotDriverRoute = store.driverRoute
            }
            guard tab == .map, !hasInitializedMapCamera else { return }
            hasInitializedMapCamera = true
            focusMapOnPickup(animated: false)
        }
        .onChange(of: locationTracker.effectiveLocation?.coordinate.latitude ?? 0) { _, _ in
            guard tabBar.selectedTab == .map else { return }
            guard pendingCenterOnPassenger else { return }
            applyPassengerLocationIfAvailable()
        }
        .onChange(of: store.morningPickups.count) { _, _ in
            viewModel.loadSavedPickup(from: store, session: session)
        }
        .onChange(of: store.isTripActive) { wasActive, isActive in
            viewModel.onTripActiveChanged(
                wasActive: wasActive,
                isActive: isActive,
                attendance: myAttendance
            )
        }
        .overlay {
            if viewModel.showTripStartedAttendanceSheet {
                ZStack(alignment: .bottom) {
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()
                        .onTapGesture { viewModel.dismissTripAttendanceSheet() }

                    TripStartedAttendanceSheet(
                        driverName: store.driverLocation?.driverName ?? "Sürücü",
                        isLoading: viewModel.isUpdatingAttendance,
                        selectedComing: viewModel.pendingAttendanceSelection == .coming,
                        selectedNotComing: viewModel.pendingAttendanceSelection == .notComing,
                        onSelectComing: {
                            Task {
                                await viewModel.updateAttendance(status: .coming, store: store, session: session)
                            }
                        },
                        onSelectNotComing: {
                            Task {
                                await viewModel.updateAttendance(status: .notComing, store: store, session: session)
                            }
                        },
                        onDismiss: { viewModel.dismissTripAttendanceSheet() }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .ignoresSafeArea(edges: .bottom)
                .animation(.easeInOut(duration: 0.28), value: viewModel.showTripStartedAttendanceSheet)
            }
        }
        .sheet(isPresented: $showMyServices) {
            MyServicesView()
                .environment(session)
        }
    }

    private func centerOnMyLocation() {
        pendingCenterOnPassenger = true
        locationTracker.requestPassengerSingleLocation()
        applyPassengerLocationIfAvailable()
    }

    private func openMapFocusedOnPickup() {
        tabBar.select(.map)
        hasInitializedMapCamera = true
        focusMapOnPickup(animated: false)
    }

    /// Harita sekmesine dönünce kayıtlı / taslak biniş noktasına odaklan.
    private func focusMapOnPickup(animated: Bool) {
        viewModel.loadSavedPickup(from: store, session: session)

        guard let pickup = viewModel.draftPickupCoordinate ?? savedMorningPickup?.coordinate else {
            centerOnMyLocation()
            return
        }

        var coordinates = [pickup]
        if store.isTripActive, let driver = store.driverLocation?.coordinate {
            let pickupLocation = CLLocation(latitude: pickup.latitude, longitude: pickup.longitude)
            let driverLocation = CLLocation(latitude: driver.latitude, longitude: driver.longitude)
            if pickupLocation.distance(from: driverLocation) <= 20_000 {
                coordinates.append(driver)
            }
        }

        applyMapRegion(for: coordinates, animated: animated)
    }

    private func applyPassengerLocationIfAvailable() {
        guard let coord = locationTracker.effectiveLocation?.coordinate else { return }
        pendingCenterOnPassenger = false
        viewModel.draftPickupCoordinate = coord
        let region = MKCoordinateRegion(
            center: coord,
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
        setMapRegion(region, animated: true)
    }

    // MARK: - Top Bar

    private var passengerTopBar: some View {
        RoleNavBar(chrome: NeonTheme.passengerChrome, onMenuTap: { showMyServices = true }) {
            if store.isTripActive {
                liveBadge
            }
        }
    }

    private var liveBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(NeonTheme.passengerChrome.statusAccent)
                .frame(width: 8, height: 8)
                .shadow(color: NeonTheme.passengerChrome.statusAccent.opacity(0.8), radius: 4)
            Text("CANLI")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundStyle(NeonTheme.passengerChrome.statusAccent)
        }
    }

    // MARK: - Service Tab

    private var serviceTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                serviceHeaderSection

                attendanceSection

                pickupSummarySection
            }
            .padding(24)
        }
    }

    private var serviceHeaderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text((profile?.groupName ?? "Servis").uppercased())
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(NeonTheme.onSurface)

            HStack(spacing: 8) {
                Circle()
                    .fill(store.isTripActive ? NeonTheme.secondary : NeonTheme.outline)
                    .frame(width: 8, height: 8)
                    .shadow(color: store.isTripActive ? NeonTheme.secondary.opacity(0.8) : .clear, radius: 4)

                if let location = store.driverLocation {
                    Text("\(location.driverName.uppercased()) • \(location.updatedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(NeonTheme.secondary)
                } else {
                    Text(store.isTripActive ? "Sürücü konumu bekleniyor" : "Servis henüz başlamadı")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(NeonTheme.onSurfaceVariant)
                }
            }
        }
    }

    private var attendanceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("BUGÜN GELECEK MİSİNİZ?")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .tracking(2)
                .foregroundStyle(NeonTheme.onSurfaceVariant)

            if myAttendance != .unknown {
                HStack(spacing: 6) {
                    Image(systemName: myAttendance.iconName)
                        .foregroundStyle(attendanceColor(myAttendance))
                    Text("Seçiminiz: \(myAttendance.title)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(NeonTheme.onSurface)
                }
            }

            HStack(spacing: 8) {
                attendanceButton(
                    title: "GELİYORUM",
                    icon: "checkmark.circle.fill",
                    accent: NeonTheme.secondary,
                    status: .coming,
                    isSelected: myAttendance == .coming
                )
                attendanceButton(
                    title: "GELMİYORUM",
                    icon: "xmark.circle.fill",
                    accent: Color(hex: 0xFF4444),
                    status: .notComing,
                    isSelected: myAttendance == .notComing
                )
            }

            Text(store.isTripActive
                 ? "Seçiminiz sürücüye anında iletilir."
                 : "Servis başlayınca seçim yapabilirsiniz.")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .tracking(1)
                .foregroundStyle(NeonTheme.outline)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(16)
        .background(NeonTheme.surfaceContainer)
        .overlay {
            Rectangle()
                .strokeBorder(NeonTheme.secondary.opacity(0.22), lineWidth: 1)
        }
    }

    private var pickupSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BİNİŞ NOKTASI")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(NeonTheme.onSurfaceVariant)

            if let savedMorningPickup {
                Label(
                    "Kayıtlı: \(savedMorningPickup.updatedAt.formatted(date: .omitted, time: .shortened))",
                    systemImage: "checkmark.circle.fill"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NeonTheme.secondary)
            } else {
                Text("Henüz biniş noktası kaydetmediniz.")
                    .font(.subheadline)
                    .foregroundStyle(NeonTheme.onSurfaceVariant)
            }

            Button {
                openMapFocusedOnPickup()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "map")
                    Text(savedMorningPickup == nil ? "HARİTADA BELİRLE" : "HARİTADA DÜZENLE")
                        .tracking(1)
                }
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(NeonTheme.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .background(NeonTheme.surfaceContainerHigh)
            .overlay {
                Rectangle()
                    .strokeBorder(NeonTheme.secondary.opacity(0.45), lineWidth: 1)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(NeonTheme.surfaceContainer)
        .overlay {
            Rectangle()
                .strokeBorder(NeonTheme.outline.opacity(0.25), lineWidth: 1)
        }
    }

    // MARK: - Map Tab

    private var mapTab: some View {
        ZStack {
            PassengerLiveMap(
                driverLocation: tabBar.selectedTab == .map ? store.driverLocation : mapSnapshotDriverLocation,
                driverRoute: tabBar.selectedTab == .map ? store.driverRoute : mapSnapshotDriverRoute,
                isTripActive: store.isTripActive,
                selectedCoordinate: $viewModel.draftPickupCoordinate,
                savedPickup: savedMorningPickup,
                cameraPosition: $mapPosition,
                isActive: tabBar.selectedTab == .map,
                autoFitOnAppear: false
            )
            .ignoresSafeArea()

            NeonMapOverlay()

            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    compactTopInfo

                    Spacer(minLength: 0)

                    if store.isTripActive {
                        liveBadge
                    }

                    mapControls
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Spacer(minLength: 0)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            mapPickupBar
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
    }

    private var mapPickupBar: some View {
        VStack(spacing: 8) {
            Text("Haritaya dokunarak biniş noktanızı seçin.")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(NeonTheme.onSurfaceVariant)
                .frame(maxWidth: .infinity, alignment: .center)

            savePickupButton
        }
        .padding(14)
        .background(NeonTheme.surfaceContainer.opacity(0.82))
        .background(.ultraThinMaterial.opacity(0.14))
        .overlay {
            Rectangle()
                .strokeBorder(NeonTheme.secondary.opacity(0.22), lineWidth: 1)
        }
    }

    // MARK: - Settings Tab

    private var settingsTab: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    if let code = profile?.groupCode {
                        settingsRow(title: "Servis Kodu", value: code) {
                            viewModel.copyGroupCode(code)
                        }
                    }

                    if let name = profile?.name {
                        settingsRow(title: "Adınız", value: name, action: nil)
                    }

                    if let groupName = profile?.groupName {
                        settingsRow(title: "Servis", value: groupName, action: nil)
                    }

                    NotificationSettingsRow()

                    Button {
                        viewModel.requestSignOut {
                            Task { await viewModel.signOut(store: store, session: session) }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Çıkış Yap")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .foregroundStyle(Color(hex: 0xFF4444))
                        .padding(16)
                        .background(NeonTheme.surfaceContainer)
                        .overlay {
                            Rectangle()
                                .strokeBorder(Color(hex: 0xFF4444).opacity(0.3), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(24)
            }

            settingsDeleteAccountFooter
        }
    }

    private var settingsDeleteAccountFooter: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(NeonTheme.outline.opacity(0.25))
                .frame(height: 1)

            deleteAccountButton
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 8)
        }
        .background(NeonTheme.background)
    }

    private var deleteAccountButton: some View {
        Button {
            viewModel.requestDeleteAccount {
                Task {
                    await viewModel.deleteAccount(
                        store: store,
                        session: session,
                        authService: authService
                    )
                }
            }
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("Hesabı Sil")
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(16)
            .background(Color(hex: 0xFF4444))
        }
        .buttonStyle(.plain)
    }

    private func settingsRow(title: String, value: String, action: (() -> Void)?) -> some View {
        Button {
            action?()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title.uppercased())
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(NeonTheme.onSurfaceVariant)
                    Text(value)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(NeonTheme.onSurface)
                }
                Spacer()
                if action != nil {
                    Image(systemName: "doc.on.doc")
                        .foregroundStyle(NeonTheme.secondary)
                }
            }
            .padding(16)
            .background(NeonTheme.surfaceContainer)
            .overlay {
                Rectangle()
                    .strokeBorder(NeonTheme.outline.opacity(0.3), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }

    // MARK: - Shared components

    private var compactTopInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(NeonTheme.secondary)
                    .frame(width: 6, height: 6)
                    .shadow(color: NeonTheme.secondary.opacity(0.8), radius: 4)
                Text((profile?.groupName ?? "Servis").uppercased())
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(NeonTheme.onSurface)
                    .lineLimit(1)
            }

            if let location = store.driverLocation {
                Text("\(location.driverName.uppercased()) • \(location.updatedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(NeonTheme.secondary)
                    .lineLimit(1)
            } else {
                Text(store.isTripActive ? "Konum bekleniyor" : "Servis bekliyor")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(NeonTheme.onSurfaceVariant)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: 200, alignment: .leading)
        .background(NeonTheme.surfaceContainer.opacity(0.72))
        .background(.ultraThinMaterial.opacity(0.12))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(NeonTheme.secondary)
                .frame(width: 3)
        }
        .overlay {
            Rectangle()
                .strokeBorder(NeonTheme.secondary.opacity(0.22), lineWidth: 1)
        }
    }

    private var mapControls: some View {
        VStack(spacing: 8) {
            mapControlButton(icon: "plus") { zoomMap(by: 0.7) }
            mapControlButton(icon: "minus") { zoomMap(by: 1.35) }
            mapControlButton(icon: "location.fill", highlighted: true) { centerOnMyLocation() }
        }
    }

    private func mapControlButton(icon: String, highlighted: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(highlighted ? NeonTheme.secondary : NeonTheme.onSurface)
                .frame(width: 40, height: 40)
                .background(NeonTheme.surfaceContainer.opacity(0.92))
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

    private var savePickupButton: some View {
        Button {
            Task { await viewModel.saveMorningPickup(store: store, session: session) }
        } label: {
            Group {
                if viewModel.isSavingPickup {
                    ProgressView().tint(NeonTheme.secondary)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.and.ellipse")
                        Text("BİNİŞ NOKTAMI KAYDET")
                            .tracking(1)
                    }
                    .foregroundStyle(NeonTheme.secondary)
                    .shadow(color: NeonTheme.secondary.opacity(0.45), radius: 6)
                }
            }
            .font(.system(size: 12, weight: .heavy, design: .rounded))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .background(NeonTheme.surfaceContainerHigh.opacity(0.9))
        .overlay {
            Rectangle()
                .strokeBorder(NeonTheme.secondary.opacity(0.45), lineWidth: 1)
        }
        .disabled(viewModel.isSavingPickup || viewModel.draftPickupCoordinate == nil)
        .opacity(viewModel.draftPickupCoordinate == nil ? 0.45 : 1)
        .buttonStyle(.plain)
    }

    private func attendanceButton(
        title: String,
        icon: String,
        accent: Color,
        status: AttendanceStatus,
        isSelected: Bool
    ) -> some View {
        Button {
            Task { await viewModel.updateAttendance(status: status, store: store, session: session) }
        } label: {
            VStack(spacing: 8) {
                if viewModel.isUpdatingAttendance && myAttendance != status {
                    ProgressView().tint(accent)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 26))
                        .shadow(color: isSelected ? accent.opacity(0.65) : .clear, radius: 8)
                }

                Text(title)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.2)
            }
            .foregroundStyle(isSelected ? accent : NeonTheme.onSurfaceVariant)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(isSelected ? accent.opacity(0.12) : NeonTheme.surfaceContainerHigh.opacity(0.85))
            .overlay {
                Rectangle()
                    .strokeBorder(isSelected ? accent.opacity(0.55) : NeonTheme.outline.opacity(0.25), lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isUpdatingAttendance || !store.isTripActive)
        .opacity(store.isTripActive ? 1 : 0.5)
    }

    // MARK: - Map helpers

    private func zoomMap(by factor: Double) {
        guard var region = mapPosition.region else { return }
        region.span.latitudeDelta = min(0.5, max(0.005, region.span.latitudeDelta * factor))
        region.span.longitudeDelta = min(0.5, max(0.005, region.span.longitudeDelta * factor))
        setMapRegion(region, animated: true)
    }

    private func fitMapCamera() {
        focusMapOnPickup(animated: true)
    }

    private func fitAllAnnotations(animated: Bool) {
        var coordinates: [CLLocationCoordinate2D] = []
        if let pickup = viewModel.draftPickupCoordinate ?? savedMorningPickup?.coordinate {
            coordinates.append(pickup)
        }
        if store.isTripActive, let driver = store.driverLocation?.coordinate {
            coordinates.append(driver)
        }
        guard !coordinates.isEmpty else {
            setMapRegion(MapDefaults.homeRegion, animated: animated)
            return
        }
        applyMapRegion(for: coordinates, animated: animated)
    }

    private func applyMapRegion(for coordinates: [CLLocationCoordinate2D], animated: Bool) {
        guard let first = coordinates.first else { return }

        let region: MKCoordinateRegion
        if coordinates.count == 1 {
            region = MKCoordinateRegion(
                center: first,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        } else {
            var minLat = first.latitude, maxLat = first.latitude
            var minLng = first.longitude, maxLng = first.longitude
            for coordinate in coordinates {
                minLat = min(minLat, coordinate.latitude)
                maxLat = max(maxLat, coordinate.latitude)
                minLng = min(minLng, coordinate.longitude)
                maxLng = max(maxLng, coordinate.longitude)
            }
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLng + maxLng) / 2),
                span: MKCoordinateSpan(
                    latitudeDelta: min(0.06, max(0.015, (maxLat - minLat) * 1.6)),
                    longitudeDelta: min(0.06, max(0.015, (maxLng - minLng) * 1.6))
                )
            )
        }

        setMapRegion(region, animated: animated)
    }

    private func setMapRegion(_ region: MKCoordinateRegion, animated: Bool) {
        if let current = mapPosition.region, regionsAreSimilar(current, region) {
            return
        }
        if animated {
            withAnimation(.easeInOut(duration: 0.25)) {
                mapPosition = .region(region)
            }
        } else {
            mapPosition = .region(region)
        }
    }

    private func regionsAreSimilar(_ lhs: MKCoordinateRegion, _ rhs: MKCoordinateRegion) -> Bool {
        let centerThreshold = 0.00015
        let spanThreshold = 0.0015
        return abs(lhs.center.latitude - rhs.center.latitude) < centerThreshold
            && abs(lhs.center.longitude - rhs.center.longitude) < centerThreshold
            && abs(lhs.span.latitudeDelta - rhs.span.latitudeDelta) < spanThreshold
            && abs(lhs.span.longitudeDelta - rhs.span.longitudeDelta) < spanThreshold
    }

    private func attendanceColor(_ status: AttendanceStatus) -> Color {
        switch status {
        case .coming: NeonTheme.secondary
        case .notComing: Color(hex: 0xFF4444)
        case .unknown: Color(hex: 0xFFE04A)
        }
    }
}

#Preview {
    PassengerHomeView()
        .environment(ShuttleStore())
        .environment(UserSession.shared)
}
