import CoreLocation
import SwiftUI

#if canImport(UIKit)
import UIKit
import CoreMotion
#endif

struct DriverPassengerStats {
    let total: Int = 15
    let coming: Int
    let notComing: Int
    let unknown: Int

    var capacityOccupied: Int {
        coming + unknown
    }

    var comingProgress: Double {
        guard total > 0 else { return 0 }
        return Double(capacityOccupied) / Double(total)
    }
}

@MainActor
@Observable
final class DriverHomeViewModel: BaseViewModel {
    var showTripDurationSheet = false
    var activeStartPermissionSheet: DriverStartPermissionSheet?
    var pendingTripDurationSheetAfterPermissions = false
    var selectedTripDurationHours = 2.0
    private var isRequestingMotionAuthorization = false

    enum DriverStartPermissionSheet: Equatable {
        case locationForeground
        case locationAlways
        case motion
    }

    private enum StartTripPermissionGate {
        case locationForeground
        case locationAlways
        case motion
        case ready
    }

    private func needsDriverAlwaysLocationUpgrade(locationTracker: LocationTracker) -> Bool {
        locationTracker.refreshAuthorizationStatus()
        return locationTracker.hasWhenInUseAuthorization && !locationTracker.canDriverStartTrip
    }

    @discardableResult
    private func presentDriverAlwaysLocationSheetIfNeeded(locationTracker: LocationTracker) -> Bool {
        guard needsDriverAlwaysLocationUpgrade(locationTracker: locationTracker) else { return false }
        pendingTripDurationSheetAfterPermissions = true
        activeStartPermissionSheet = .locationAlways
        return true
    }

    private func startTripPermissionGate(locationTracker: LocationTracker) -> StartTripPermissionGate {
        locationTracker.refreshAuthorizationStatus()

        switch locationTracker.authorizationStatus {
        case .notDetermined, .denied, .restricted:
            return .locationForeground
        case .authorizedWhenInUse:
            return .locationAlways
        case .authorizedAlways:
            break
        @unknown default:
            return .locationForeground
        }

        let motion = MotionActivityService.shared
        if motion.canRequestAuthorization {
            motion.refreshAuthorization()
            if !motion.isAuthorized {
                return .motion
            }
        }
        return .ready
    }

    private func presentStartTripPermissionGate(
        _ gate: StartTripPermissionGate,
        locationTracker: LocationTracker
    ) {
        switch gate {
        case .locationForeground:
            pendingTripDurationSheetAfterPermissions = true
            locationTracker.refreshAuthorizationStatus()
            switch locationTracker.authorizationStatus {
            case .notDetermined:
                // Yalnızca sistem diyaloğu — bottom sheet kullanıcı cevabından sonra.
                activeStartPermissionSheet = nil
                locationTracker.requestWhenInUsePermissionIfNeeded()
            case .denied, .restricted:
                activeStartPermissionSheet = .locationForeground
            case .authorizedWhenInUse:
                pendingTripDurationSheetAfterPermissions = true
                activeStartPermissionSheet = .locationAlways
            default:
                presentStartTripPermissionGate(
                    startTripPermissionGate(locationTracker: locationTracker),
                    locationTracker: locationTracker
                )
            }
        case .locationAlways:
            pendingTripDurationSheetAfterPermissions = true
            activeStartPermissionSheet = .locationAlways
        case .motion:
            pendingTripDurationSheetAfterPermissions = true
            Task { await presentMotionStep(locationTracker: locationTracker) }
        case .ready:
            activeStartPermissionSheet = nil
            pendingTripDurationSheetAfterPermissions = false
            showTripDurationSheet = true
        }
    }

    func dismissActiveStartPermissionSheet() {
        activeStartPermissionSheet = nil
    }

    /// Motion: önce sistem diyaloğu; reddedilirse bottom sheet.
    private func presentMotionStep(locationTracker: LocationTracker) async {
        let motion = MotionActivityService.shared
        guard motion.canRequestAuthorization else {
            presentStartTripPermissionGate(.ready, locationTracker: locationTracker)
            return
        }
        motion.refreshAuthorization()
        switch motion.authorizationStatus {
        case .notDetermined:
            activeStartPermissionSheet = nil
            await motion.requestAuthorizationIfNeeded()
            motion.refreshAuthorization()
            guard pendingTripDurationSheetAfterPermissions else { return }
            if motion.isAuthorized {
                presentStartTripPermissionGate(
                    startTripPermissionGate(locationTracker: locationTracker),
                    locationTracker: locationTracker
                )
            } else if motion.authorizationStatus == .denied || motion.authorizationStatus == .restricted {
                activeStartPermissionSheet = .motion
            } else {
                activeStartPermissionSheet = nil
            }
        case .denied, .restricted:
            activeStartPermissionSheet = .motion
        case .authorized:
            presentStartTripPermissionGate(
                startTripPermissionGate(locationTracker: locationTracker),
                locationTracker: locationTracker
            )
        @unknown default:
            activeStartPermissionSheet = .motion
        }
    }

    private func continueStartTripPermissionFlow(locationTracker: LocationTracker) {
        if presentDriverAlwaysLocationSheetIfNeeded(locationTracker: locationTracker) { return }
        let gate = startTripPermissionGate(locationTracker: locationTracker)
        if gate == .motion {
            Task { await presentMotionStep(locationTracker: locationTracker) }
        } else {
            presentStartTripPermissionGate(gate, locationTracker: locationTracker)
        }
    }

    func configure(session: UserSession) {
        title = session.profile?.groupName ?? L10n.service
        navigationBarStyle = .neonDriver
        hidesNavigationBar = true
        usesLargeTitle = false
    }

    func passengerStats(from members: [ShuttleMember], store: ShuttleStore) -> DriverPassengerStats {
        let passengers = members.filter { $0.role == .passenger }
        return DriverPassengerStats(
            coming: passengers.filter { store.serviceDayAttendance(for: $0) == .coming }.count,
            notComing: passengers.filter { store.serviceDayAttendance(for: $0) == .notComing }.count,
            unknown: passengers.filter { store.serviceDayAttendance(for: $0) == .unknown }.count
        )
    }

    func onAppear(store: ShuttleStore, session: UserSession, locationTracker: LocationTracker) {
        configure(session: session)
        locationTracker.refreshAuthorizationStatus()
        if locationTracker.hasWhenInUseAuthorization {
            locationTracker.requestDriverSingleLocation()
        }
        if let groupID = session.profile?.groupID,
           let driverName = session.profile?.name {
            store.startListening(groupID: groupID)
            Task {
                await store.reconcileActiveTripIfExpired(
                    groupID: groupID,
                    driverName: driverName,
                    locationTracker: locationTracker
                )
            }
        }
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

    func requestDeleteAccount(onConfirm: @escaping () -> Void) {
        showConfirm(
            title: L10n.deleteAccount,
            message: L10n.deleteAccountConfirmMessage,
            confirmTitle: L10n.deleteAccountPermanently,
            destructive: true,
            onConfirm: onConfirm
        )
    }

    func deleteAccount(
        store: ShuttleStore,
        session: UserSession,
        authService: AuthService,
        locationTracker: LocationTracker
    ) async {
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

        let groupID = profile.primaryGroupID
        if store.isTripActive, !groupID.isEmpty {
            await store.stopTrip(
                groupID: groupID,
                driverName: profile.name,
                locationTracker: locationTracker
            )
        }

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

    func updateName(_ newName: String, store: ShuttleStore, session: UserSession) {
        guard let memberID = session.profile?.memberID else { return }
        let groupID = session.profile?.primaryGroupID.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let fallback = session.profile?.groupID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let resolvedGroupID = groupID.isEmpty ? fallback : groupID
        guard !resolvedGroupID.isEmpty else { return }

        Task {
            do {
                try await store.updateMemberName(groupID: resolvedGroupID, memberID: memberID, newName: newName)
                showSuccess(L10n.nameUpdated)
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    func handleTripControlTap(store: ShuttleStore, session: UserSession, locationTracker: LocationTracker) async {
        guard let profile = session.profile,
              let groupID = profile.groupID else { return }
        let driverName = profile.name

        if store.isTripActive {
            await store.stopTrip(groupID: groupID, driverName: driverName, locationTracker: locationTracker)
            showSuccess(L10n.shuttleStopped)
            return
        }

        locationTracker.refreshAuthorizationStatus()
        MotionActivityService.shared.refreshAuthorization()
        continueStartTripPermissionFlow(locationTracker: locationTracker)
    }

    func requestDriverAlwaysPermission(locationTracker: LocationTracker) {
        continueStartTripPermissionFlow(locationTracker: locationTracker)
    }

    func onDriverPermissionsUpdated(locationTracker: LocationTracker) {
        locationTracker.refreshAuthorizationStatus()
        MotionActivityService.shared.refreshAuthorization()
        if locationTracker.hasWhenInUseAuthorization {
            locationTracker.requestDriverSingleLocation()
        }
        guard pendingTripDurationSheetAfterPermissions else { return }
        if locationTracker.authorizationStatus == .notDetermined {
            return
        }
        if isRequestingMotionAuthorization {
            return
        }
        if presentDriverAlwaysLocationSheetIfNeeded(locationTracker: locationTracker) {
            return
        }
        continueStartTripPermissionFlow(locationTracker: locationTracker)
    }

    func confirmStartTrip(store: ShuttleStore, session: UserSession, locationTracker: LocationTracker) async {
        guard let profile = session.profile,
              let groupID = profile.groupID else { return }
        let driverName = profile.name

        let gate = startTripPermissionGate(locationTracker: locationTracker)
        guard gate == .ready else {
            pendingTripDurationSheetAfterPermissions = true
            showTripDurationSheet = false
            if gate == .motion {
                Task { await presentMotionStep(locationTracker: locationTracker) }
            } else {
                presentStartTripPermissionGate(gate, locationTracker: locationTracker)
            }
            return
        }

        activeStartPermissionSheet = nil
        pendingTripDurationSheetAfterPermissions = false
        showTripDurationSheet = false

        do {
            try await store.startTrip(
                groupID: groupID,
                driverName: driverName,
                durationHours: selectedTripDurationHours,
                locationTracker: locationTracker
            )
            BusTrackerAnalytics.tripStarted(durationHours: selectedTripDurationHours)
            let hoursLabel = L10n.hoursLabel(selectedTripDurationHours)
            showSuccess(L10n.shuttleStartedAutoStop(hoursLabel))
        } catch {
            showError(L10n.shuttleStartFailed)
        }
    }

    func signOut(store: ShuttleStore, session: UserSession, locationTracker: LocationTracker) async {
        if store.isTripActive,
           let profile = session.profile,
           let groupID = profile.groupID {
            await store.stopTrip(groupID: groupID, driverName: profile.name, locationTracker: locationTracker)
        }
        store.stopListening()
        await session.signOut()
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
