import CoreLocation
import SwiftUI

struct DriverHomeView: BaseView {
    @Environment(ShuttleStore.self) private var store
    @Environment(UserSession.self) private var session
    @Environment(LocationTracker.self) private var locationTracker
    @Environment(AuthService.self) private var authService
    @State var viewModel = DriverHomeViewModel()
    @State var tabBar = DriverTabBarController()
    @State private var showMyServices = false
    @State private var isCreatingInviteLink = false
    @State private var showLanguagePicker = false
    @State private var locationForegroundGuidePhase: DriverLocationForegroundGuidePhase = .guide
    @State private var alwaysLocationGuidePhase: DriverAlwaysLocationGuidePhase = .guide
    @State private var motionGuidePhase: DriverMotionGuidePhase = .guide

    private var profile: UserProfile? { session.profile }

    private var passengers: [ShuttleMember] {
        store.members.filter { $0.role == .passenger }
    }

    private var stats: DriverPassengerStats {
        _ = store.attendanceRevision
        return viewModel.passengerStats(from: store.members, store: store)
    }

    private func updateDriverMotionMonitoring() {
        guard store.isTripActive,
              let groupID = profile?.primaryGroupID ?? profile?.groupID,
              let memberID = profile?.memberID,
              !groupID.isEmpty else {
            MotionActivityService.shared.stopMonitoring()
            return
        }

        MotionActivityService.shared.updateMonitoring(
            isEnabled: true,
            role: .driver,
            groupID: groupID,
            memberID: memberID,
            store: store
        )
    }

    private var canConfirmTripStart: Bool {
        locationTracker.refreshAuthorizationStatus()
        let motion = MotionActivityService.shared
        motion.refreshAuthorization()
        return locationTracker.canDriverStartTrip && (!motion.canRequestAuthorization || motion.isAuthorized)
    }

    func content() -> some View {
        VStack(spacing: 0) {
            if tabBar.selectedTab != .map {
                driverTopBar
            }

            Group {
                switch tabBar.selectedTab {
                case .passengers:
                    passengersTab
                case .map:
                    mapTab
                case .settings:
                    settingsTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            DriverTabBar(controller: tabBar)
        }
        .ignoresSafeArea(.keyboard)
        .onAppear {
            viewModel.onAppear(store: store, session: session, locationTracker: locationTracker)
            updateDriverMotionMonitoring()
        }
        .onChange(of: store.isTripActive) { _, _ in
            updateDriverMotionMonitoring()
        }
        .onDisappear {
            MotionActivityService.shared.stopMonitoring()
        }
        .onChange(of: viewModel.activeStartPermissionSheet) { _, sheet in
            guard sheet != nil else { return }
            locationForegroundGuidePhase = .guide
            alwaysLocationGuidePhase = .guide
            motionGuidePhase = .guide
        }
        .overlay {
            if let sheet = viewModel.activeStartPermissionSheet {
                ZStack(alignment: .bottom) {
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()
                        .onTapGesture { viewModel.dismissActiveStartPermissionSheet() }

                    Group {
                        switch sheet {
                        case .locationForeground:
                            DriverLocationForegroundGuideSheet(
                                phase: locationForegroundGuidePhase,
                                onOpenSettings: {
                                    locationForegroundGuidePhase = .waitingSettingsReturn
                                    locationTracker.openAppSettings()
                                },
                                onDismiss: {
                                    locationForegroundGuidePhase = .guide
                                    viewModel.dismissActiveStartPermissionSheet()
                                }
                            )
                        case .locationAlways:
                            DriverAlwaysLocationGuideSheet(
                                phase: alwaysLocationGuidePhase,
                                needsAlwaysUpgradeFromWhenInUse: true,
                                onOpenSettings: {
                                    alwaysLocationGuidePhase = .waitingSettingsReturn
                                    locationTracker.openAppSettings()
                                },
                                onDismiss: {
                                    alwaysLocationGuidePhase = .guide
                                    viewModel.dismissActiveStartPermissionSheet()
                                }
                            )
                        case .motion:
                            DriverMotionGuideSheet(
                                phase: motionGuidePhase,
                                onOpenSettings: {
                                    motionGuidePhase = .waitingSettingsReturn
                                    locationTracker.openAppSettings()
                                },
                                onDismiss: {
                                    motionGuidePhase = .guide
                                    viewModel.dismissActiveStartPermissionSheet()
                                }
                            )
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .ignoresSafeArea(edges: .bottom)
                .animation(.easeInOut(duration: 0.28), value: viewModel.activeStartPermissionSheet)
            }
        }
        .overlay {
            if viewModel.showTripDurationSheet {
                ZStack(alignment: .bottom) {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                        .onTapGesture { viewModel.showTripDurationSheet = false }

                    TripDurationBottomSheet(
                        selectedHours: $viewModel.selectedTripDurationHours,
                        isLoading: store.isLoading,
                        canStartTrip: canConfirmTripStart,
                        onConfirm: {
                            Task {
                                await viewModel.confirmStartTrip(
                                    store: store,
                                    session: session,
                                    locationTracker: locationTracker
                                )
                            }
                        },
                        onDismiss: { viewModel.showTripDurationSheet = false }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .ignoresSafeArea(edges: .bottom)
                .animation(.easeInOut(duration: 0.28), value: viewModel.showTripDurationSheet)
            }
        }
        .onChange(of: locationTracker.authorizationStatus) { _, _ in
            locationTracker.refreshAuthorizationStatus()
            MotionActivityService.shared.refreshAuthorization()
            viewModel.onDriverPermissionsUpdated(locationTracker: locationTracker)
        }
#if canImport(UIKit)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            locationTracker.refreshAuthorizationStatus()
            MotionActivityService.shared.refreshAuthorization()
            if viewModel.activeStartPermissionSheet != nil {
                switch viewModel.activeStartPermissionSheet {
                case .locationForeground:
                    if locationForegroundGuidePhase == .waitingSettingsReturn {
                        locationForegroundGuidePhase = .guide
                    }
                case .locationAlways:
                    if alwaysLocationGuidePhase == .waitingSettingsReturn {
                        alwaysLocationGuidePhase = .guide
                    }
                case .motion:
                    if motionGuidePhase == .waitingSettingsReturn {
                        motionGuidePhase = .guide
                    }
                case .none:
                    break
                }
            }
            viewModel.onDriverPermissionsUpdated(locationTracker: locationTracker)
        }
#endif
        .sheet(isPresented: $showMyServices) {
            MyServicesView()
                .environment(session)
        }
    }

    // MARK: - Top Bar

    private var driverTopBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text((profile?.groupName ?? L10n.service).uppercased())
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(NeonTheme.onSurface)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Circle()
                        .fill(store.isTripActive ? NeonTheme.driverChrome.statusAccent : NeonTheme.outline)
                        .frame(width: 6, height: 6)
                        .shadow(color: store.isTripActive ? NeonTheme.driverChrome.statusAccent.opacity(0.8) : .clear, radius: 3)

                    Text(store.isTripActive ? L10n.shuttleActive : L10n.shuttleNotStarted)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(store.isTripActive ? NeonTheme.driverChrome.statusAccent : NeonTheme.onSurfaceVariant)
                }
            }

            Spacer()

            if store.isTripActive {
                HStack(spacing: 6) {
                    Circle()
                        .fill(NeonTheme.driverChrome.statusAccent)
                        .frame(width: 8, height: 8)
                        .shadow(color: NeonTheme.driverChrome.statusAccent.opacity(0.8), radius: 4)
                    Text(L10n.active)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(NeonTheme.driverChrome.statusAccent)
                }
            }
        }
        .frame(height: 56)
        .padding(.horizontal, 24)
        .background(NeonTheme.driverChrome.navBarBackground.opacity(0.97))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(NeonTheme.driverChrome.navBarDivider)
                .frame(height: 1)
                .shadow(color: NeonTheme.driverChrome.navBarDividerShadow, radius: 6)
        }
    }

    private var pulseDot: some View {
        Circle()
            .fill(store.isTripActive ? NeonTheme.driverChrome.statusAccent : NeonTheme.outline)
            .frame(width: 8, height: 8)
            .shadow(color: store.isTripActive ? NeonTheme.driverChrome.statusAccent.opacity(0.8) : .clear, radius: 4)
    }

    // MARK: - Passengers Tab

    private var passengersTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                serviceTitleSection
                serviceCodeCard
                tripControlSection
                statsGrid

                if passengers.isEmpty {
                    emptyPassengersState
                } else {
                    passengerListSection
                }

                if locationTracker.authorizationStatus == .denied || locationTracker.authorizationStatus == .restricted {
                    locationWarning
                } else if store.isTripActive, locationTracker.needsAlwaysAuthorization {
                    backgroundLocationWarning
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
    }

    private var serviceTitleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                pulseDot
                Text(L10n.serviceNameLabel)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(NeonTheme.onSurfaceVariant)
            }
            Text((profile?.groupName ?? L10n.service).uppercased())
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(NeonTheme.onSurface)
                .tracking(-0.5)
        }
    }

    private var serviceCodeCard: some View {
        VStack(spacing: 16) {
            Text(L10n.serviceCodeLabel)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(3)
                .foregroundStyle(NeonTheme.primary)
                .shadow(color: NeonTheme.primary.opacity(0.6), radius: 6)

            Text((profile?.groupCode ?? "------").uppercased())
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .tracking(6)
                .foregroundStyle(NeonTheme.onSurface)
                .minimumScaleFactor(0.7)

            HStack(spacing: 8) {
                if let code = profile?.groupCode {
                    Button {
                        Task { await shareServiceInvite(code) }
                    } label: {
                        if isCreatingInviteLink {
                            codeActionLabel(title: L10n.preparing, icon: "hourglass", accent: NeonTheme.primary, filled: true)
                        } else {
                            codeActionLabel(title: L10n.share, icon: "square.and.arrow.up", accent: NeonTheme.primary, filled: true)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isCreatingInviteLink)

                    Button {
                        if let code = profile?.groupCode {
                            viewModel.copyServiceCode(code)
                        }
                    } label: {
                        codeActionLabel(title: L10n.copy, icon: "doc.on.doc", accent: NeonTheme.onSurfaceVariant, filled: false)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background {
            Rectangle()
                .fill(NeonTheme.surfaceContainer.opacity(0.7))
                .background(.ultraThinMaterial.opacity(0.15))
        }
        .overlay {
            Rectangle()
                .strokeBorder(NeonTheme.primary.opacity(0.2), lineWidth: 1)
        }
        .shadow(color: NeonTheme.primary.opacity(0.15), radius: 12)
    }

    private func codeActionLabel(title: String, icon: String, accent: Color, filled: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.5)
        }
        .foregroundStyle(accent)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background {
            Rectangle()
                .fill(filled ? NeonTheme.primary.opacity(0.1) : NeonTheme.surfaceContainer)
        }
        .overlay {
            Rectangle()
                .strokeBorder(accent.opacity(filled ? 0.4 : 0.3), lineWidth: 1)
        }
    }

    private var statsGrid: some View {
        HStack(spacing: 8) {
            statCard(
                title: L10n.statComing,
                value: "\(stats.coming)",
                valueColor: NeonTheme.secondary,
                accentBorder: NeonTheme.secondary.opacity(0.3),
                trailingIcon: "checkmark.circle.fill"
            )
            statCard(
                title: L10n.statNotComing,
                value: "\(stats.notComing)",
                valueColor: Color(hex: 0xFF4444),
                accentBorder: Color(hex: 0xFF4444).opacity(0.3),
                trailingIcon: "xmark.circle.fill"
            )
            statCard(
                title: L10n.statUnknown,
                value: "\(stats.unknown)",
                valueColor: Color(hex: 0xFFE04A),
                accentBorder: Color(hex: 0xFFE04A).opacity(0.35),
                trailingIcon: "questionmark.circle.fill"
            )
        }
    }

    private func statCard(
        title: String,
        value: String,
        valueColor: Color,
        accentBorder: Color,
        progress: Double? = nil,
        trailingIcon: String? = nil,
        footnote: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .tracking(0.5)
                .foregroundStyle(NeonTheme.onSurfaceVariant)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(valueColor)
                    .shadow(color: valueColor == NeonTheme.secondary ? NeonTheme.secondary.opacity(0.5) : .clear, radius: 6)
                if let trailingIcon {
                    Image(systemName: trailingIcon)
                        .font(.caption)
                        .foregroundStyle(valueColor.opacity(0.85))
                }
            }

            if let progress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(NeonTheme.surfaceContainerHigh)
                            .frame(height: 2)
                        Rectangle()
                            .fill(NeonTheme.secondary)
                            .frame(width: geo.size.width * progress, height: 2)
                            .shadow(color: NeonTheme.secondary.opacity(0.8), radius: 4)
                    }
                }
                .frame(height: 2)
            } else if let footnote {
                Text(footnote)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(NeonTheme.onSurfaceVariant)
                    .italic()
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NeonTheme.surfaceContainer)
        .overlay {
            Rectangle()
                .strokeBorder(accentBorder, lineWidth: 1)
        }
        .shadow(color: valueColor == NeonTheme.secondary ? NeonTheme.secondary.opacity(0.1) : .clear, radius: 6)
    }

    private var emptyPassengersState: some View {
        VStack(spacing: 20) {
            ZStack {
                Rectangle()
                    .strokeBorder(NeonTheme.primary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                    .frame(width: 80, height: 80)
                Image(systemName: "shareplay.slash")
                    .font(.system(size: 36))
                    .foregroundStyle(NeonTheme.primary.opacity(0.6))
            }

            VStack(spacing: 6) {
                Text(L10n.waitingForPassengers)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(NeonTheme.onSurfaceVariant)
                Text(L10n.waitingForPassengersHint)
                    .font(.caption)
                    .foregroundStyle(NeonTheme.outline)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 220)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .opacity(0.85)
    }

    private var passengerListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.passengerList)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(NeonTheme.onSurfaceVariant)

                Spacer()

                HStack(spacing: 4) {
                    Text(store.currentDriverService.session.icon)
                        .font(.system(size: 12))
                    Text(store.currentDriverService.relativeDisplayName().uppercased())
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .tracking(1)
                }
                .foregroundStyle(NeonTheme.primary)
            }

            VStack(spacing: 0) {
                ForEach(passengers) { member in
                    let attendance = store.serviceDayAttendance(for: member)
                    HStack(spacing: 12) {
                        Image(systemName: attendance.iconName)
                            .font(.title3)
                            .foregroundStyle(attendanceColor(attendance))
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(NeonTheme.onSurface)
                            Text(attendance.title)
                                .font(.caption)
                                .foregroundStyle(NeonTheme.onSurfaceVariant)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(NeonTheme.surfaceContainer.opacity(0.6))

                    if member.id != passengers.last?.id {
                        Rectangle()
                            .fill(NeonTheme.outline.opacity(0.2))
                            .frame(height: 1)
                    }
                }
            }
            .overlay {
                Rectangle()
                    .strokeBorder(NeonTheme.outline.opacity(0.3), lineWidth: 1)
            }
        }
    }

    private var tripControlSection: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    await viewModel.handleTripControlTap(
                        store: store,
                        session: session,
                        locationTracker: locationTracker
                    )
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: store.isTripActive ? "stop.fill" : "bolt.fill")
                        .font(.title3)
                    Text(store.isTripActive ? L10n.stopShuttle : L10n.startShuttle)
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .tracking(2)
                }
                .foregroundStyle(store.isTripActive ? Color(hex: 0xFF4444) : NeonTheme.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(NeonTheme.background)
                .overlay {
                    Rectangle()
                        .strokeBorder(store.isTripActive ? Color(hex: 0xFF4444) : NeonTheme.primary, lineWidth: 2)
                }
                .shadow(color: (store.isTripActive ? Color(hex: 0xFF4444) : NeonTheme.primary).opacity(0.25), radius: 10)
            }
            .buttonStyle(.plain)

            Text(tripStatusCaption)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .tracking(2)
                .foregroundStyle(NeonTheme.outline)
                .frame(maxWidth: .infinity)
        }
        .padding(.top, 4)
    }

    private var tripStatusCaption: String {
        if store.isTripActive {
            if let end = store.plannedTripEndAt {
                return L10n.tripEndTime(end.formatted(date: .omitted, time: .shortened))
            }
            return L10n.sharingLocation
        }
        return L10n.selectDurationOnStart
    }

    private var locationWarning: some View {
        Text(L10n.locationPermissionDenied)
            .font(.caption)
            .foregroundStyle(Color(hex: 0xFF4444))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var backgroundLocationWarning: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.backgroundLocationWarning)
                .font(.caption)
                .foregroundStyle(Color(hex: 0xFFE04A))
            Button(L10n.enableAlwaysLocation) {
                viewModel.requestDriverAlwaysPermission(locationTracker: locationTracker)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(NeonTheme.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Map Tab

    private var mapDriverLocation: DriverLocation? {
        resolveDriverMapLocation(
            firestoreLocation: store.driverLocation,
            deviceLocation: locationTracker.effectiveLocation,
            driverName: profile?.name ?? L10n.driver
        )
    }

    private var mapTab: some View {
        DriverMapTabView(
            driverLocation: mapDriverLocation,
            driverRoute: store.driverRoute,
            morningPickups: passengerMorningPickups,
            stats: stats,
            isTripActive: store.isTripActive
        )
        .onAppear {
            if locationTracker.hasWhenInUseAuthorization {
                locationTracker.requestDriverSingleLocation()
            }
        }
    }

    private var passengerMorningPickups: [MorningPickup] {
        let passengerIDs = Set(passengers.map(\.id))
        return store.morningPickups.filter { pickup in
            guard passengerIDs.contains(pickup.memberID) else { return false }
            guard let member = passengers.first(where: { $0.id == pickup.memberID }) else { return false }
            return store.serviceDayAttendance(for: member) != .notComing
        }
    }

    // MARK: - Settings Tab

    private var settingsTab: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    if let code = profile?.groupCode, !code.isEmpty {
                        SettingsServiceCodeRow(code: code) {
                            viewModel.copyServiceCode(code)
                        }
                        SettingsInviteShareRow(serviceCode: code) { message in
                            viewModel.showError(message)
                        }
                    }

                    if let memberID = profile?.memberID,
                       let name = store.members.first(where: { $0.id == memberID })?.name ?? profile?.name {
                        SettingsEditableNameRow(
                            title: L10n.settingsYourName,
                            value: .constant(name)
                        ) { newName in
                            viewModel.updateName(newName, store: store, session: session)
                        }
                    }

                    SettingsNavigationRow(
                        title: L10n.myShuttles,
                        value: profile?.groupName
                    ) {
                        showMyServices = true
                    }

                    NotificationSettingsRow()

                    LanguageSettingsRow(showPicker: $showLanguagePicker)

                    SettingsSignOutRow {
                        viewModel.requestSignOut {
                            Task { await viewModel.signOut(store: store, session: session, locationTracker: locationTracker) }
                        }
                    }
                }
                .padding(24)
            }

            SettingsDeleteAccountFooter {
                viewModel.requestDeleteAccount {
                    Task {
                        await viewModel.deleteAccount(
                            store: store,
                            session: session,
                            authService: authService,
                            locationTracker: locationTracker
                        )
                    }
                }
            }
        }
        .overlay {
            if showLanguagePicker {
                LanguagePickerOverlay(isPresented: $showLanguagePicker)
                    .animation(.easeInOut(duration: 0.28), value: showLanguagePicker)
            }
        }
    }

    @ViewBuilder
    private func settingsRow(title: String, value: String, action: (() -> Void)?) -> some View {
        let label = HStack {
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

        if let action {
            Button(action: action) {
                label
            }
            .buttonStyle(.plain)
        } else {
            label
        }
    }

    private func shareServiceInvite(_ code: String) async {
#if os(iOS) || os(visionOS)
        guard !isCreatingInviteLink else { return }
        isCreatingInviteLink = true
        defer { isCreatingInviteLink = false }

        print("[Smler] Paylaş butonu serviceCode=\(code)")
        switch await SmlerDeepLinkService.shared.prepareShare(serviceCode: code) {
        case .success(let message, let url):
            print("[Smler] Paylaş OK url=\(url.absoluteString)")
            SharePresenter.present(items: [url, message])
        case .failure(let error):
            print("[Smler] Paylaş HATA (ekranda da gösterildi): \(error)")
            viewModel.showError(error)
        }
#endif
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
    DriverHomeView()
        .environment(ShuttleStore())
        .environment(UserSession.shared)
        .environment(LocationTracker())
}
