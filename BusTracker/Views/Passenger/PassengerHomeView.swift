import CoreMotion
import MapKit
import SwiftUI
import UserNotifications

struct PassengerHomeView: BaseView {
    @Environment(ShuttleStore.self) private var store
    @Environment(UserSession.self) private var session
    @Environment(AuthService.self) private var authService
    @Environment(LocationTracker.self) private var locationTracker
    @Environment(SmlerInviteCoordinator.self) private var smlerInviteCoordinator
    @State var viewModel = PassengerHomeViewModel()
    @State var tabBar = PassengerTabBarController()
    @State private var mapPosition: MapCameraPosition = MapDefaults.homeMapPosition
    @State private var lastKnownMapRegion = MapDefaults.homeRegion
    @State private var showMyServices = false
    @State private var myServicesInviteCode = ""
    @State private var openAddServiceFromInvite = false
    @State private var pendingCenterOnPassenger = false
    @State private var hasInitializedMapCamera = false
    /// Konum tuşu: false = bir sonraki basış birincil odak, true = bir sonraki basış alternatif odak.
    @State private var pickupWeather: PassengerWeatherCardModel?
    @State private var pickupWeatherLoading = false
    @State private var showLanguagePicker = false
    @State private var showHolidayModePicker = false
    @State private var showSparseModeSuggestionSheet = false
    @State private var sparseModeComingDays = 0
    @State private var holidayModeSelectedEndDate = Date()
    @State private var isSavingHolidayMode = false
    @State private var locationForegroundGuidePhase: DriverLocationForegroundGuidePhase = .guide
    @State private var motionGuidePhase: DriverMotionGuidePhase = .guide
    @State private var notificationGuidePhase: DriverNotificationGuidePhase = .guide
    @State private var showComingBlockedWithoutPickupHint = false
#if canImport(UIKit)
    @Environment(\.scenePhase) private var scenePhase
#endif

    // MARK: - ViewModel Shortcuts
    private var profile: UserProfile? { viewModel.profile }
    private var myMember: ShuttleMember? { viewModel.myMember }
    private var nextTwoServices: [UpcomingService] { viewModel.nextTwoServices }
    private var currentDriverService: UpcomingService { viewModel.currentDriverService }
    private var currentServiceRawAttendance: AttendanceStatus { viewModel.currentServiceRawAttendance }
    private var currentServiceEffectiveAttendance: AttendanceStatus { viewModel.currentServiceEffectiveAttendance }
    private var isHolidayModeActive: Bool { viewModel.isHolidayModeActive }
    private var memberLoaded: Bool { viewModel.memberLoaded }
    private var resolvedGroupID: String { viewModel.resolvedGroupID }
    private var holidayModeCardSubtitle: String { viewModel.holidayModeCardSubtitle }
    private var holidayModeCardDetail: String { viewModel.holidayModeCardDetail }
    private var savedMorningPickup: MorningPickup? { viewModel.savedMorningPickup }
    private var hasSavedMorningPickup: Bool { viewModel.hasSavedMorningPickup }

    private func rawAttendance(for service: UpcomingService) -> AttendanceStatus {
        viewModel.rawAttendance(for: service)
    }
    private func effectiveAttendance(for service: UpcomingService) -> AttendanceStatus {
        viewModel.effectiveAttendance(for: service)
    }
    private func isComingSelected(for service: UpcomingService) -> Bool {
        viewModel.isComingSelected(for: service)
    }
    private func isNotComingSelected(for service: UpcomingService) -> Bool {
        viewModel.isNotComingSelected(for: service)
    }

    private var sparseSuggestionTaskKey: String {
        "\(memberLoaded)-\(isHolidayModeActive)-\(profile?.memberID ?? "")-\(resolvedGroupID)"
    }

    func content() -> some View {
        passengerTabRoot
            .overlay { tripAttendanceOverlay }
            .overlay { sparseModeSuggestionOverlay }
            .overlay { holidayModePickerOverlay }
            .overlay { actionPermissionOverlay }
            .modifier(PassengerSmlerInviteModifier(
                showMyServices: $showMyServices,
                myServicesInviteCode: $myServicesInviteCode,
                openAddServiceFromInvite: $openAddServiceFromInvite,
                session: session,
                onAppearCheck: presentMyServicesForSmlerInviteIfNeeded
            ))
    }

    private var passengerTabRoot: some View {
        passengerTabRootWithPermissionObservers
    }

    private var passengerTabRootContent: some View {
        VStack(spacing: 0) {
            if tabBar.selectedTab != .map {
                passengerTopBar
            }

            Group {
                switch tabBar.selectedTab {
                case .map:
                    PassengerMapTab(
                        viewModel: viewModel,
                        savedMorningPickup: savedMorningPickup,
                        hasSavedMorningPickup: hasSavedMorningPickup,
                        currentServiceEffectiveAttendance: currentServiceEffectiveAttendance,
                        onSelectServiceTab: { tabBar.select(.service) },
                        onSavePickup: {
                            viewModel.requestSaveMorningPickup(
                                store: store,
                                session: session,
                                locationTracker: locationTracker
                            )
                        },
                        mapPosition: $mapPosition,
                        onCameraRegionChange: { lastKnownMapRegion = $0 },
                        focusOnSavedPickupOrDevice: { animated in focusOnSavedPickupOrDevice(animated: animated) },
                        focusOnDriverLocation: { animated in focusOnDriverLocation(animated: animated) }
                    )
                    .id("passenger-map-tab")
                case .service:
                    PassengerServiceTab(
                        viewModel: viewModel,
                        nextTwoServices: nextTwoServices,
                        isHolidayModeActive: isHolidayModeActive,
                        holidayModeCardSubtitle: holidayModeCardSubtitle,
                        holidayModeCardDetail: holidayModeCardDetail,
                        savedMorningPickup: savedMorningPickup,
                        showComingBlockedWithoutPickupHint: $showComingBlockedWithoutPickupHint,
                        showHolidayModePicker: $showHolidayModePicker,
                        pickupWeather: $pickupWeather,
                        pickupWeatherLoading: $pickupWeatherLoading,
                        onRequestComingAttendance: { service in requestComingAttendance(for: service) },
                        onRequestNotComingAttendance: { service in requestNotComingAttendance(for: service) },
                        onOpenMapForPickup: { openMapFocusedOnPickup() }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(NeonTheme.background)
                case .settings:
                    PassengerSettingsTab(
                        viewModel: viewModel,
                        showLanguagePicker: $showLanguagePicker,
                        showMyServices: $showMyServices
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(NeonTheme.background)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            PassengerTabBar(controller: tabBar)
        }
        .ignoresSafeArea(.keyboard)
    }

    private var passengerTabRootWithAppearAndTasks: some View {
        passengerTabRootContent
            .onAppear {
                presentMyServicesForSmlerInviteIfNeeded()
                viewModel.onAppear(store: store, session: session)
                viewModel.loadSavedPickup(from: store, session: session)
                promptMapTabLocationIfNeeded()
                if PushNotificationRouter.consumePendingOpenPassengerMap() {
                    openMapFromTripStartedNotification()
                }
                if PushNotificationRouter.consumePendingOpenSparseModeSheet() {
                    openSparseModeSheetFromNotification()
                }
                syncTripAttendanceState()
                updatePassengerMotionMonitoring()
            }
#if canImport(UIKit)
            .onReceive(NotificationCenter.default.publisher(for: PushNotificationRouter.openPassengerMapNotification)) { _ in
                openMapFromTripStartedNotification()
            }
            .onReceive(NotificationCenter.default.publisher(for: PushNotificationRouter.openSparseModeSheetNotification)) { _ in
                openSparseModeSheetFromNotification()
            }
#endif
            .task(id: sparseSuggestionTaskKey) {
                let groupID = resolvedGroupID
                guard memberLoaded,
                      let memberID = profile?.memberID,
                      !groupID.isEmpty
                else { return }
                try? await Task.sleep(for: .seconds(1.2))
                guard let prompt = await SparseModeSuggestion.evaluate(
                    groupID: groupID,
                    memberID: memberID,
                    holidayModeActive: isHolidayModeActive
                ) else { return }
                sparseModeComingDays = prompt.comingDays
                showSparseModeSuggestionSheet = true
                await SparseModeSuggestionNotifier.postNotificationIfNeeded(
                    memberID: memberID,
                    prompt: prompt
                )
            }
            .task(id: tripAttendancePromptKey) {
                guard memberLoaded else { return }
                try? await Task.sleep(for: .milliseconds(350))
                syncTripAttendanceState()
            }
    }

    private var passengerTabRootWithTripObservers: some View {
        passengerTabRootWithAppearAndTasks
#if canImport(UIKit)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                handlePassengerForegroundReturn()
            }
#endif
            .onChange(of: currentServiceRawAttendance) { _, _ in
                syncTripAttendanceState()
            }
            .onChange(of: store.members.count) { _, _ in
                syncTripAttendanceState()
            }
            .onChange(of: tabBar.selectedTab) { _, tab in
                guard tab == .map else { return }
                promptMapTabLocationIfNeeded()
                focusMapOnPickup(animated: !hasInitializedMapCamera)
                hasInitializedMapCamera = true
            }
            .onChange(of: locationTracker.effectiveLocation?.coordinate.latitude ?? 0) { _, _ in
                guard tabBar.selectedTab == .map else { return }
                guard pendingCenterOnPassenger else { return }
                applyPassengerLocationIfAvailable()
            }
            .onChange(of: store.morningPickups.count) { _, _ in
                viewModel.loadSavedPickup(from: store, session: session)
                if hasSavedMorningPickup {
                    showComingBlockedWithoutPickupHint = false
                }
                guard tabBar.selectedTab == .map, !store.isTripActive else { return }
                focusMapOnPickup(animated: false)
            }
            .onChange(of: store.isTripActive) { wasActive, isActive in
                viewModel.onTripActiveChanged(
                    wasActive: wasActive,
                    isActive: isActive,
                    attendance: currentServiceRawAttendance,
                    holidayModeActive: isHolidayModeActive
                )
                updatePassengerMotionMonitoring()
            }
#if canImport(UIKit)
            .onChange(of: scenePhase) { _, _ in
                updatePassengerMotionMonitoring()
            }
#endif
            .onDisappear {
                MotionActivityService.shared.stopMonitoring()
            }
    }

    private var passengerTabRootWithPermissionObservers: some View {
        passengerTabRootWithTripObservers
            .onChange(of: locationTracker.authorizationStatus) { _, _ in
                refreshPassengerActionPermissions()
            }
            .onChange(of: motionAuthorizationStatus) { _, _ in
                refreshPassengerActionPermissions()
            }
            .onChange(of: notificationAuthorizationStatus) { _, _ in
                refreshPassengerActionPermissions()
            }
            .onChange(of: viewModel.activeActionPermissionSheet) { _, sheet in
                guard sheet != nil else { return }
                locationForegroundGuidePhase = .guide
                motionGuidePhase = .guide
                notificationGuidePhase = .guide
            }
    }

    private var motionAuthorizationStatus: CMAuthorizationStatus {
        MotionActivityService.shared.authorizationStatus
    }

    private var notificationAuthorizationStatus: UNAuthorizationStatus {
        NotificationService.shared.authorizationStatus
    }

    private func handlePassengerForegroundReturn() {
        syncTripAttendanceState()
        guard viewModel.hasPendingGatedAction || viewModel.activeActionPermissionSheet != nil else { return }
        if locationForegroundGuidePhase == .waitingSettingsReturn {
            locationForegroundGuidePhase = .guide
        }
        if motionGuidePhase == .waitingSettingsReturn {
            motionGuidePhase = .guide
        }
        if notificationGuidePhase == .waitingSettingsReturn {
            notificationGuidePhase = .guide
        }
        refreshPassengerActionPermissions()
    }

    private func refreshPassengerActionPermissions() {
        locationTracker.refreshAuthorizationStatus()
        MotionActivityService.shared.refreshAuthorization()
        viewModel.onPassengerPermissionsUpdated(locationTracker: locationTracker)
    }

    /// Harita sekmesi açılınca konum izni (sistem diyaloğu). Reddedilirse buton akışında bottom sheet.
    private func promptMapTabLocationIfNeeded() {
        locationTracker.refreshAuthorizationStatus()
        guard locationTracker.authorizationStatus == .notDetermined else { return }
        locationTracker.requestWhenInUsePermissionIfNeeded()
    }

    private func updatePassengerMotionMonitoring() {
#if canImport(UIKit)
        let isForeground = scenePhase == .active
#else
        let isForeground = true
#endif
        let groupID = profile?.primaryGroupID ?? profile?.groupID ?? ""
        let memberID = profile?.memberID ?? ""
        let shouldMonitor = isForeground && !groupID.isEmpty && !memberID.isEmpty

        MotionActivityService.shared.updateMonitoring(
            isEnabled: shouldMonitor,
            role: .passenger,
            groupID: groupID,
            memberID: memberID,
            store: store
        )
    }

    @ViewBuilder
    private var sparseModeSuggestionOverlay: some View {
        if showSparseModeSuggestionSheet {
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .onTapGesture { showSparseModeSuggestionSheet = false }

                SparseModeSuggestionSheet(
                    comingDays: sparseModeComingDays,
                    onConfirm: {
                        BusTrackerAnalytics.sparseModePrompt(action: "ok")
                        showSparseModeSuggestionSheet = false
                        tabBar.select(.service)
                        showHolidayModePicker = true
                    },
                    onLater: {
                        BusTrackerAnalytics.sparseModePrompt(action: "later")
                        showSparseModeSuggestionSheet = false
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            .ignoresSafeArea(edges: .bottom)
            .zIndex(4)
            .animation(.easeInOut(duration: 0.28), value: showSparseModeSuggestionSheet)
        }
    }

    @ViewBuilder
    private var tripAttendanceOverlay: some View {
        if viewModel.showTripStartedAttendanceSheet {
            tripAttendanceSheetOverlay
        }
    }

    private var tripAttendanceSheetOverlay: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { viewModel.dismissTripAttendanceSheet() }

            TripStartedAttendanceSheet(
                driverName: store.driverLocation?.driverName ?? L10n.driver,
                isLoading: viewModel.isUpdatingAttendance,
                selectedComing: viewModel.pendingAttendanceSelection == .coming,
                selectedNotComing: viewModel.pendingAttendanceSelection == .notComing,
                onSelectComing: {
                    requestComingAttendance(for: currentDriverService)
                },
                onSelectNotComing: {
                    requestNotComingAttendance(for: currentDriverService)
                }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .ignoresSafeArea(edges: .bottom)
        .animation(.easeInOut(duration: 0.28), value: viewModel.showTripStartedAttendanceSheet)
    }

    private func presentMyServicesForSmlerInviteIfNeeded() {
        guard let code = smlerInviteCoordinator.pendingAddServiceCode else { return }
        myServicesInviteCode = code
        openAddServiceFromInvite = true
        showMyServices = true
        smlerInviteCoordinator.clearAddServicePending()
    }

    /// Servis + katılım verisi geldikçe “Geliyorum / Gelmiyorum” sheet’ini değerlendir.
    private var tripAttendancePromptKey: String {
        let memberID = profile?.memberID ?? ""
        let memberLoaded = store.members.contains { $0.id == memberID }
        return "\(store.isTripActive)-\(currentServiceRawAttendance.rawValue)-\(memberLoaded)-\(isHolidayModeActive)-\(store.members.count)-\(store.attendanceRevision)"
    }

    private func syncTripAttendanceState() {
        guard memberLoaded else { return }
        viewModel.syncTripAttendanceState(
            isTripActive: store.isTripActive,
            holidayModeActive: isHolidayModeActive,
            rawAttendance: currentServiceRawAttendance
        )
    }

    /// Konum oku: kayıtlı biniş noktası; yoksa cihaz konumu.
    private func focusOnSavedPickupOrDevice(animated: Bool) {
        if let saved = savedMorningPickup?.coordinate {
            centerMap(on: saved, animated: animated)
            return
        }
        centerOnCurrentLocation(animated: animated)
    }

    private var showsDriverMapButton: Bool {
        store.isTripActive
    }

    /// Minibüs: sürücünün anlık konumu (servis aktif veya canlı konum geliyorsa).
    private func focusOnDriverLocation(animated: Bool) {
        guard let driver = store.driverLocation?.coordinate else { return }
        centerMap(on: driver, animated: animated)
    }

    private func centerOnCurrentLocation(animated: Bool) {
        pendingCenterOnPassenger = true
        locationTracker.requestPassengerSingleLocation()
        if let coordinate = locationTracker.effectiveLocation?.coordinate {
            pendingCenterOnPassenger = false
            centerMap(on: coordinate, animated: animated)
        }
    }

    private func centerMap(on coordinate: CLLocationCoordinate2D, animated: Bool) {
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
        setMapRegion(region, animated: animated, force: true)
    }

    private func centerOnMyLocation() {
        focusOnSavedPickupOrDevice(animated: true)
    }

    private func openMapFocusedOnPickup() {
        openMapFromTripStartedNotification()
    }

    /// Servis yola çıktı bildirimine basınca harita sekmesi (+ sefer aktifse odak).
    private func openMapFromTripStartedNotification() {
        tabBar.select(.map)
        hasInitializedMapCamera = true
        focusMapOnPickup(animated: false)
        syncTripAttendanceState()
    }

    /// Seyrek kullanım bildirimine basınca öneri sheet'i açılır.
    private func openSparseModeSheetFromNotification() {
        tabBar.select(.service)
        Task {
            guard let memberID = profile?.memberID,
                  !resolvedGroupID.isEmpty,
                  let prompt = await SparseModeSuggestion.evaluate(
                    groupID: resolvedGroupID,
                    memberID: memberID,
                    holidayModeActive: isHolidayModeActive
                  )
            else { return }
            sparseModeComingDays = prompt.comingDays
            showSparseModeSuggestionSheet = true
        }
    }

    /// Harita sekmesine dönünce biniş noktasına odaklan; servis pasifken yalnızca yolcu pini.
    private func focusMapOnPickup(animated: Bool) {
        viewModel.loadSavedPickup(from: store, session: session)

        guard let pickup = viewModel.draftPickupCoordinate ?? savedMorningPickup?.coordinate else {
            if store.isTripActive {
                centerOnMyLocation()
            }
            return
        }

        guard store.isTripActive else {
            applyMapRegion(for: [pickup], animated: animated)
            return
        }

        var coordinates = [pickup]
        if let driver = store.driverLocation?.coordinate {
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
        centerMap(on: coord, animated: true)
    }

    // MARK: - Top Bar

    private var passengerTopBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text((profile?.groupName ?? L10n.service).uppercased())
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(NeonTheme.onSurface)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Circle()
                        .fill(store.isTripActive ? NeonTheme.secondary : NeonTheme.outline)
                        .frame(width: 6, height: 6)
                        .shadow(color: store.isTripActive ? NeonTheme.secondary.opacity(0.8) : .clear, radius: 3)

                    Text(store.isTripActive ? L10n.shuttleActive : L10n.shuttleNotStarted)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(store.isTripActive ? NeonTheme.secondary : NeonTheme.onSurfaceVariant)
                }
            }

            Spacer()

            if store.isTripActive {
                liveBadge
            }
        }
        .frame(height: 56)
        .padding(.horizontal, 24)
        .background(NeonTheme.passengerChrome.navBarBackground.opacity(0.97))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(NeonTheme.passengerChrome.navBarDivider)
                .frame(height: 1)
                .shadow(color: NeonTheme.passengerChrome.navBarDividerShadow, radius: 6)
        }
    }

    private var liveBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(NeonTheme.passengerChrome.statusAccent)
                .frame(width: 8, height: 8)
                .shadow(color: NeonTheme.passengerChrome.statusAccent.opacity(0.8), radius: 4)
            Text(L10n.live)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundStyle(NeonTheme.passengerChrome.statusAccent)
        }
    }

    @ViewBuilder
    private var holidayModePickerOverlay: some View {
        if showHolidayModePicker {
            HolidayModePickerOverlay(
                isPresented: $showHolidayModePicker,
                isHolidayActive: isHolidayModeActive,
                activeEndDateKey: myMember?.holidayModeEndDate,
                selectedEndDate: $holidayModeSelectedEndDate,
                isSaving: isSavingHolidayMode,
                onConfirm: {
                    Task { await saveHolidayMode() }
                },
                onEndHoliday: {
                    Task { await clearHolidayMode() }
                }
            )
            .animation(.easeInOut(duration: 0.28), value: showHolidayModePicker)
        }
    }

    private func saveHolidayMode() async {
        guard let profile = session.profile else { return }
        let groupID = profile.primaryGroupID.isEmpty ? (profile.groupID ?? "") : profile.primaryGroupID
        guard !groupID.isEmpty else {
            viewModel.showError(L10n.shuttleInfoNotFound)
            return
        }

        isSavingHolidayMode = true
        defer { isSavingHolidayMode = false }

        do {
            try await store.setHolidayMode(
                groupID: groupID,
                memberID: profile.memberID,
                endDate: holidayModeSelectedEndDate
            )
            showHolidayModePicker = false
            BusTrackerAnalytics.holidayModeSaved()
            viewModel.showSuccess(L10n.holidayModeSaved)
        } catch {
            viewModel.showError(L10n.saveFailed)
        }
    }

    private func clearHolidayMode() async {
        guard let profile = session.profile else { return }
        let groupID = profile.primaryGroupID.isEmpty ? (profile.groupID ?? "") : profile.primaryGroupID
        guard !groupID.isEmpty else { return }

        isSavingHolidayMode = true
        defer { isSavingHolidayMode = false }

        do {
            try await store.clearHolidayMode(groupID: groupID, memberID: profile.memberID)
            showHolidayModePicker = false
            BusTrackerAnalytics.holidayModeEnded()
            viewModel.showSuccess(L10n.holidayModeEnded)
        } catch {
            viewModel.showError(L10n.updateFailed)
        }
    }

    // MARK: - Permission Overlay

    private var actionPermissionOverlay: some View {
        Group {
            if let sheet = viewModel.activeActionPermissionSheet {
                ZStack(alignment: .bottom) {
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()
                        .onTapGesture { viewModel.dismissActiveActionPermissionSheet() }

                    Group {
                        switch sheet {
                        case .notification:
                            DriverNotificationGuideSheet(
                                phase: notificationGuidePhase,
                                bodyGuide: L10n.passengerNotificationPermissionBody,
                                onOpenSettings: {
                                    notificationGuidePhase = .waitingSettingsReturn
                                    locationTracker.openAppSettings()
                                },
                                onDismiss: {
                                    notificationGuidePhase = .guide
                                    viewModel.dismissActiveActionPermissionSheet()
                                }
                            )
                        case .locationForeground:
                            DriverLocationForegroundGuideSheet(
                                phase: locationForegroundGuidePhase,
                                bodyGuide: L10n.passengerLocationForegroundBody,
                                onOpenSettings: {
                                    locationForegroundGuidePhase = .waitingSettingsReturn
                                    locationTracker.openAppSettings()
                                },
                                onDismiss: {
                                    locationForegroundGuidePhase = .guide
                                    viewModel.dismissActiveActionPermissionSheet()
                                }
                            )
                        case .motion:
                            DriverMotionGuideSheet(
                                phase: motionGuidePhase,
                                bodyGuide: L10n.passengerMotionPermissionBody,
                                onOpenSettings: {
                                    motionGuidePhase = .waitingSettingsReturn
                                    locationTracker.openAppSettings()
                                },
                                onDismiss: {
                                    motionGuidePhase = .guide
                                    viewModel.dismissActiveActionPermissionSheet()
                                }
                            )
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .ignoresSafeArea(edges: .bottom)
                .animation(.easeInOut(duration: 0.28), value: viewModel.activeActionPermissionSheet)
            }
        }
    }

    // MARK: - Attendance Actions

    private func requestComingAttendance(for service: UpcomingService) {
        guard hasSavedMorningPickup else {
            showComingBlockedWithoutPickupHint = true
            tabBar.select(.service)
            viewModel.dismissTripAttendanceSheet()
            return
        }

        showComingBlockedWithoutPickupHint = false
        viewModel.requestUpdateAttendance(
            status: .coming,
            dateKey: service.dateKey,
            store: store,
            session: session,
            locationTracker: locationTracker
        )
    }

    private func requestNotComingAttendance(for service: UpcomingService) {
        showComingBlockedWithoutPickupHint = false
        viewModel.requestUpdateAttendance(
            status: .notComing,
            dateKey: service.dateKey,
            store: store,
            session: session,
            locationTracker: locationTracker
        )
    }

    // MARK: - Map helpers

    private func resolvedMapRegion() -> MKCoordinateRegion {
        if let region = mapPosition.region {
            return region
        }
        return lastKnownMapRegion
    }

    private func zoomMap(by factor: Double) {
        var region = resolvedMapRegion()
        region.span.latitudeDelta = min(0.5, max(0.005, region.span.latitudeDelta * factor))
        region.span.longitudeDelta = min(0.5, max(0.005, region.span.longitudeDelta * factor))
        setMapRegion(region, animated: true, force: true)
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

    private func setMapRegion(_ region: MKCoordinateRegion, animated: Bool, force: Bool = false) {
        lastKnownMapRegion = region
        if !force, let current = mapPosition.region, regionsAreSimilar(current, region) {
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

extension View {
    func mapInfoBoxStyle(accent: Color, compact: Bool = false) -> some View {
        padding(.horizontal, compact ? 8 : 12)
            .padding(.vertical, compact ? 5 : 10)
            .frame(maxWidth: compact ? nil : 200, alignment: .leading)
            .fixedSize(horizontal: compact, vertical: false)
            .background(NeonTheme.surfaceContainer.opacity(0.72))
            .background(.ultraThinMaterial.opacity(0.12))
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(accent)
                    .frame(width: compact ? 2 : 3)
            }
            .overlay {
                Rectangle()
                    .strokeBorder(accent.opacity(0.22), lineWidth: 1)
            }
    }
}

#Preview {
    PassengerHomeView()
        .environment(ShuttleStore())
        .environment(UserSession.shared)
}
