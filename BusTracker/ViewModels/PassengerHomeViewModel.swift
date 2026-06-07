import CoreLocation
import SwiftUI

#if canImport(UIKit)
import UIKit
import CoreMotion
#endif

@MainActor
@Observable
final class PassengerHomeViewModel: BaseViewModel {
    var showTripStartedAttendanceSheet = false
    var pendingAttendanceSelection: AttendanceStatus?
    var isUpdatingAttendance = false
    private var didPromptAttendanceThisTrip = false
    var isSavingPickup = false
    var draftPickupCoordinate: CLLocationCoordinate2D?
    var activeActionPermissionSheet: PassengerActionPermissionSheet?
    private var pendingGatedAction: PendingGatedAction?
    private var pendingActionStore: ShuttleStore?
    private var pendingActionSession: UserSession?
    private var isRequestingNotificationAuthorization = false
    private var didRequestMotionForPendingAction = false
    private var actionPermissionFlowTask: Task<Void, Never>?

    // Store ve session referansları
    private(set) weak var store: ShuttleStore?
    private(set) weak var session: UserSession?

    var hasPendingGatedAction: Bool { pendingGatedAction != nil }

    enum PassengerActionPermissionSheet: Equatable {
        case notification
        case locationForeground
        case motion
    }

    private enum PendingGatedAction: Equatable {
        case savePickup
        case updateAttendance(AttendanceStatus, dateKey: String)
    }

    // MARK: - Computed Properties

    var profile: UserProfile? { session?.profile }

    var myMember: ShuttleMember? {
        guard let memberID = profile?.memberID, let store else { return nil }
        return store.members.first { $0.id == memberID }
    }

    var nextTwoServices: [UpcomingService] {
        ServiceSchedule.nextTwoServices()
    }

    var currentDriverService: UpcomingService {
        ServiceSchedule.currentDriverSession()
    }

    func rawAttendance(for service: UpcomingService) -> AttendanceStatus {
        guard let memberID = profile?.memberID, let store else { return .unknown }
        return store.rawAttendance(for: memberID, dateKey: service.dateKey)
    }

    func effectiveAttendance(for service: UpcomingService) -> AttendanceStatus {
        guard let memberID = profile?.memberID, let store else { return .unknown }
        return store.effectiveAttendance(for: memberID, dateKey: service.dateKey)
    }

    var currentServiceRawAttendance: AttendanceStatus {
        rawAttendance(for: currentDriverService)
    }

    var currentServiceEffectiveAttendance: AttendanceStatus {
        effectiveAttendance(for: currentDriverService)
    }

    func isComingSelected(for service: UpcomingService) -> Bool {
        rawAttendance(for: service) == .coming
    }

    func isNotComingSelected(for service: UpcomingService) -> Bool {
        let raw = rawAttendance(for: service)
        let effective = effectiveAttendance(for: service)
        return raw == .notComing ||
            (isHolidayModeActive && raw == .unknown && effective == .notComing)
    }

    var isHolidayModeActive: Bool {
        myMember?.isHolidayModeActive == true
    }

    var memberLoaded: Bool {
        guard let memberID = profile?.memberID, let store else { return false }
        return store.members.contains { $0.id == memberID }
    }

    var resolvedGroupID: String {
        let primary = profile?.primaryGroupID.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !primary.isEmpty { return primary }
        return profile?.groupID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    var holidayModeCardSubtitle: String {
        guard isHolidayModeActive,
              let key = myMember?.holidayModeEndDate,
              let display = HolidayMode.displayDate(endDateKey: key)
        else { return L10n.holidayModeOff }
        return L10n.holidayModeUntil(display)
    }

    var holidayModeCardDetail: String {
        guard isHolidayModeActive,
              let key = myMember?.holidayModeEndDate,
              let display = HolidayMode.displayDate(endDateKey: key)
        else { return L10n.holidayModeCardDetailOff }
        return L10n.holidayModeCardDetailActive(display)
    }

    var savedMorningPickup: MorningPickup? {
        guard let memberID = profile?.memberID, let store else { return nil }
        return store.morningPickup(for: memberID)
    }

    var hasSavedMorningPickup: Bool {
        savedMorningPickup != nil
    }

    // MARK: - Configuration

    func configure(session: UserSession) {
        title = session.profile?.groupName ?? L10n.service
        navigationBarStyle = .neonPassenger
        hidesNavigationBar = true
        usesLargeTitle = false
        embedsInNavigationStack = false
    }

    func onAppear(store: ShuttleStore, session: UserSession) {
        self.store = store
        self.session = session
        configure(session: session)
        let groupID = resolvedGroupID(from: session.profile)
        if !groupID.isEmpty {
            store.startListening(groupID: groupID)
        }
    }

    private func resolvedGroupID(from profile: UserProfile?) -> String {
        let primary = profile?.primaryGroupID.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !primary.isEmpty { return primary }
        return profile?.groupID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    func updateName(_ newName: String) {
        guard let memberID = profile?.memberID else { return }
        let groupID = resolvedGroupID
        guard !groupID.isEmpty else { return }

        Task {
            do {
                try await store?.updateMemberName(groupID: groupID, memberID: memberID, newName: newName)
                showSuccess(L10n.nameUpdated)
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    func onTripActiveChanged(
        wasActive: Bool,
        isActive: Bool,
        attendance: AttendanceStatus,
        holidayModeActive: Bool
    ) {
        if !isActive {
            didPromptAttendanceThisTrip = false
            showTripStartedAttendanceSheet = false
            return
        }
        if isActive && !wasActive {
            syncTripAttendanceState(
                isTripActive: true,
                holidayModeActive: holidayModeActive,
                rawAttendance: attendance
            )
        }
    }

    func presentTripAttendanceSheetIfNeeded(
        isTripActive: Bool,
        attendance: AttendanceStatus,
        holidayModeActive: Bool
    ) {
        guard isTripActive, !holidayModeActive, attendance == .unknown, !didPromptAttendanceThisTrip else { return }
        didPromptAttendanceThisTrip = true
        showTripStartedAttendanceSheet = true
    }

    func syncTripAttendanceState(
        isTripActive: Bool,
        holidayModeActive: Bool,
        rawAttendance: AttendanceStatus
    ) {
        guard isTripActive else { return }
        presentTripAttendanceSheetIfNeeded(
            isTripActive: isTripActive,
            attendance: rawAttendance,
            holidayModeActive: holidayModeActive
        )
    }

    func dismissTripAttendanceSheet() {
        showTripStartedAttendanceSheet = false
    }

    func requestSignOut(onConfirm: @escaping () -> Void) {
        showConfirm(
            title: L10n.signOut,
            message: L10n.signOutConfirmMessage,
            confirmTitle: L10n.signOut,
            destructive: true,
            onConfirm: onConfirm
        )
    }

    // MARK: - Hesap Silme (App Store 5.1.1(v) için gerekli)
    func requestDeleteAccount(onConfirm: @escaping () -> Void) {
        showConfirm(
            title: L10n.deleteAccount,
            message: L10n.deleteAccountConfirmMessagePassenger,
            confirmTitle: L10n.deleteAccountPermanently,
            destructive: true,
            onConfirm: onConfirm
        )
    }

    func deleteAccount(store: ShuttleStore, session: UserSession, authService: AuthService) async {
        guard let profile = session.profile else { return }

        isLoading = true
        defer { isLoading = false }

#if os(iOS) || os(visionOS)
        do {
            try await authService.reauthenticateForAccountDeletion()
        } catch let error as AppleSignInError {
            if case .cancelled = error { return }
            showError(L10n.googleVerificationFailed)
            return
        } catch {
            showError(L10n.googleVerificationFailed)
            return
        }
#endif

        let userID = profile.userID

        await store.deleteUserData(profile: profile)
        let profileDeleted = await store.isUserProfileDeleted(userID: userID)
        let authRemoved = await authService.removeAccountIfPossible()

        store.stopListening()
        await session.signOut()

        presentDeleteAccountResult(profileDeleted: profileDeleted, authRemoved: authRemoved)
    }

    private func presentDeleteAccountResult(profileDeleted: Bool, authRemoved: Bool) {
        if profileDeleted || authRemoved {
            showSuccess(L10n.accountDeletedSuccess)
        } else {
            showError(L10n.accountDeleteFailed)
        }
    }

    private func requiresNotificationGate(for action: PendingGatedAction) -> Bool {
        switch action {
        case .savePickup:
            return true
        case .updateAttendance(let status, _):
            return status == .coming
        }
    }

    func requestUpdateAttendance(
        status: AttendanceStatus,
        dateKey: String,
        store: ShuttleStore,
        session: UserSession,
        locationTracker: LocationTracker
    ) {
        pendingGatedAction = .updateAttendance(status, dateKey: dateKey)
        pendingActionStore = store
        pendingActionSession = session
        didRequestMotionForPendingAction = false
        continueActionPermissionFlow(locationTracker: locationTracker)
    }

    func updateAttendance(
        status: AttendanceStatus,
        dateKey: String,
        store: ShuttleStore,
        session: UserSession,
        locationTracker: LocationTracker
    ) async {
        guard locationTracker.hasWhenInUseAuthorization else { return }
        let motion = MotionActivityService.shared
        if motion.canRequestAuthorization {
            motion.refreshAuthorization()
            guard motion.isAuthorized else { return }
        }
        guard let profile = session.profile else { return }

        pendingAttendanceSelection = status
        isUpdatingAttendance = true
        defer {
            isUpdatingAttendance = false
            pendingAttendanceSelection = nil
        }

        do {
            let groupID = profile.primaryGroupID.isEmpty ? (profile.groupID ?? "") : profile.primaryGroupID
            try await store.setAttendance(
                groupID: groupID,
                memberID: profile.memberID,
                name: profile.name,
                status: status,
                dateKey: dateKey
            )
            AttendanceUsageTracker.record(
                memberID: profile.memberID,
                dateKey: dateKey,
                status: status
            )
            BusTrackerAnalytics.attendanceSelected(status: status.analyticsValue)
            showTripStartedAttendanceSheet = false
            showSuccess(L10n.choiceSaved(status.selfChoiceLabel))
        } catch {
            showError(L10n.updateFailed)
        }
    }

    func signOut(store: ShuttleStore, session: UserSession) async {
        store.stopListening()
        await session.signOut()
    }

    func loadSavedPickup(from store: ShuttleStore, session: UserSession) {
        // This function is kept for compatibility but no longer sets draftPickupCoordinate.
        // The saved pickup is shown directly from savedMorningPickup,
        // draftPickupCoordinate is only for NEW locations selected by the user.
    }

    func clearDraftPickup() {
        draftPickupCoordinate = nil
    }

    func requestSaveMorningPickup(
        store: ShuttleStore,
        session: UserSession,
        locationTracker: LocationTracker
    ) {
        guard draftPickupCoordinate != nil else {
            showError(L10n.markPickupOnMap)
            return
        }

        pendingGatedAction = .savePickup
        pendingActionStore = store
        pendingActionSession = session
        didRequestMotionForPendingAction = false
        continueActionPermissionFlow(locationTracker: locationTracker)
    }

    func dismissActiveActionPermissionSheet() {
        actionPermissionFlowTask?.cancel()
        actionPermissionFlowTask = nil
        activeActionPermissionSheet = nil
        pendingGatedAction = nil
        pendingActionStore = nil
        pendingActionSession = nil
        isRequestingNotificationAuthorization = false
        didRequestMotionForPendingAction = false
    }

    func onPassengerPermissionsUpdated(locationTracker: LocationTracker) {
        locationTracker.refreshAuthorizationStatus()
        MotionActivityService.shared.refreshAuthorization()
        guard pendingGatedAction != nil else { return }
        if isRequestingNotificationAuthorization { return }
        continueActionPermissionFlow(locationTracker: locationTracker, refreshNotifications: true)
    }

    private func continueActionPermissionFlow(
        locationTracker: LocationTracker,
        refreshNotifications: Bool = false
    ) {
        guard pendingGatedAction != nil else { return }
        actionPermissionFlowTask?.cancel()
        actionPermissionFlowTask = Task { @MainActor in
            if refreshNotifications {
                await NotificationService.shared.refreshStatus()
                guard !Task.isCancelled, pendingGatedAction != nil else { return }
            }
            await runPendingActionPermissionFlow(locationTracker: locationTracker)
        }
    }

    @MainActor
    private func runPendingActionPermissionFlow(locationTracker: LocationTracker) async {
        guard let action = pendingGatedAction else { return }

        if requiresNotificationGate(for: action) {
            guard await passNotificationPermissionGate() else { return }
        }

        guard await passLocationPermissionGate(locationTracker: locationTracker) else { return }
        guard await passMotionPermissionGate(locationTracker: locationTracker) else { return }

        activeActionPermissionSheet = nil
        executePendingGatedAction(locationTracker: locationTracker)
    }

    @MainActor
    private func passNotificationPermissionGate() async -> Bool {
        guard pendingGatedAction != nil else { return false }

        let snapshot = await NotificationService.shared.authorizationSnapshot()
        if snapshot.isEnabled {
            await syncNotificationTokenForPendingSession()
            activeActionPermissionSheet = nil
            return true
        }

        switch snapshot.status {
        case .notDetermined:
            guard !isRequestingNotificationAuthorization else { return false }
            isRequestingNotificationAuthorization = true
            activeActionPermissionSheet = nil
            await NotificationService.shared.requestPermissionAndRegister()
            isRequestingNotificationAuthorization = false
            guard pendingGatedAction != nil else { return false }

            let updated = await NotificationService.shared.authorizationSnapshot()
            if updated.isEnabled {
                await syncNotificationTokenForPendingSession()
                activeActionPermissionSheet = nil
                return true
            }
            if updated.status != .notDetermined {
                activeActionPermissionSheet = .notification
            }
            return false

        case .denied:
            activeActionPermissionSheet = .notification
            return false

        case .provisional, .ephemeral:
            await syncNotificationTokenForPendingSession()
            activeActionPermissionSheet = nil
            return true

        @unknown default:
            activeActionPermissionSheet = .notification
            return false
        }
    }

    @MainActor
    private func passLocationPermissionGate(locationTracker: LocationTracker) async -> Bool {
        guard pendingGatedAction != nil else { return false }

        locationTracker.refreshAuthorizationStatus()
        if locationTracker.hasWhenInUseAuthorization {
            if activeActionPermissionSheet == .locationForeground {
                activeActionPermissionSheet = nil
            }
            return true
        }

        switch locationTracker.authorizationStatus {
        case .notDetermined:
            // Harita sekmesi sistem diyaloğunu göstermeli; yine de sorulmadıysa bir kez dene.
            activeActionPermissionSheet = nil
            locationTracker.requestWhenInUsePermissionIfNeeded()
            return false
        case .denied, .restricted:
            activeActionPermissionSheet = .locationForeground
            return false
        @unknown default:
            activeActionPermissionSheet = .locationForeground
            return false
        }
    }

    @MainActor
    private func passMotionPermissionGate(locationTracker: LocationTracker) async -> Bool {
        guard pendingGatedAction != nil else { return false }

        let motion = MotionActivityService.shared
        guard motion.canRequestAuthorization else { return true }

        motion.refreshAuthorization()
        if motion.isAuthorized {
            didRequestMotionForPendingAction = false
            if activeActionPermissionSheet == .motion {
                activeActionPermissionSheet = nil
            }
            return true
        }

        switch motion.authorizationStatus {
        case .notDetermined:
            if !didRequestMotionForPendingAction {
                didRequestMotionForPendingAction = true
                activeActionPermissionSheet = nil
                await motion.requestAuthorizationIfNeeded()
            } else {
                motion.refreshAuthorization()
            }
            guard pendingGatedAction != nil else { return false }

            if motion.isAuthorized {
                didRequestMotionForPendingAction = false
                activeActionPermissionSheet = nil
                return true
            }
            if motion.authorizationStatus == .denied || motion.authorizationStatus == .restricted {
                didRequestMotionForPendingAction = false
                activeActionPermissionSheet = .motion
            }
            return false

        case .denied, .restricted:
            didRequestMotionForPendingAction = false
            activeActionPermissionSheet = .motion
            return false

        @unknown default:
            didRequestMotionForPendingAction = false
            activeActionPermissionSheet = .motion
            return false
        }
    }

    @MainActor
    private func syncNotificationTokenForPendingSession() async {
        guard let profile = pendingActionSession?.profile else { return }
        let groupID = profile.primaryGroupID.isEmpty ? (profile.groupID ?? "") : profile.primaryGroupID
        guard !groupID.isEmpty else { return }
        await NotificationService.shared.syncTokenIfAuthorized(
            groupID: groupID,
            memberID: profile.memberID
        )
    }

    private func executePendingGatedAction(locationTracker: LocationTracker) {
        guard let action = pendingGatedAction,
              let store = pendingActionStore,
              let session = pendingActionSession else { return }

        if requiresNotificationGate(for: action) {
            guard NotificationService.shared.isPermissionGranted else { return }
        }

        guard locationTracker.hasWhenInUseAuthorization else { return }
        let motion = MotionActivityService.shared
        if motion.canRequestAuthorization {
            motion.refreshAuthorization()
            guard motion.isAuthorized else { return }
        }

        pendingGatedAction = nil
        pendingActionStore = nil
        pendingActionSession = nil

        switch action {
        case .savePickup:
            Task { await saveMorningPickup(store: store, session: session, locationTracker: locationTracker) }
        case .updateAttendance(let status, let dateKey):
            Task { await updateAttendance(status: status, dateKey: dateKey, store: store, session: session, locationTracker: locationTracker) }
        }
    }

    func saveMorningPickup(store: ShuttleStore, session: UserSession, locationTracker: LocationTracker) async {
        guard locationTracker.hasWhenInUseAuthorization else { return }
        let motion = MotionActivityService.shared
        if motion.canRequestAuthorization {
            motion.refreshAuthorization()
            guard motion.isAuthorized else { return }
        }
        guard let profile = session.profile else { return }
        guard let coordinate = draftPickupCoordinate else {
            showError(L10n.markPickupOnMap)
            return
        }

        let groupID = profile.primaryGroupID.isEmpty ? (profile.groupID ?? "") : profile.primaryGroupID
        guard !groupID.isEmpty else {
            showError(L10n.shuttleInfoNotFound)
            return
        }

        isSavingPickup = true
        defer { isSavingPickup = false }

        do {
            try await store.setMorningPickup(
                groupID: groupID,
                memberID: profile.memberID,
                name: profile.name,
                coordinate: coordinate
            )
            // Biniş noktası kaydedildiğinde en yakın servis için "geliyorum" kaydedilir
            let nextService = ServiceSchedule.nextTwoServices().first!
            try await store.setAttendance(
                groupID: groupID,
                memberID: profile.memberID,
                name: profile.name,
                status: .coming,
                dateKey: nextService.dateKey
            )
            AttendanceUsageTracker.record(
                memberID: profile.memberID,
                dateKey: nextService.dateKey,
                status: .coming
            )
            BusTrackerAnalytics.pickupSaved()
            showTripStartedAttendanceSheet = false
            draftPickupCoordinate = nil
            showSuccess(L10n.pickupSavedComing)
        } catch {
            showError(L10n.saveFailed)
        }
    }

    func copyServiceCode(_ code: String) {
        let text = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            showError(L10n.serviceCodeNotFound)
            return
        }
        showSuccess(L10n.serviceCodeCopied)
        CopyServiceCode.copy(text)
    }
}
