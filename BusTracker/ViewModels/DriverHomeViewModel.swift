import CoreLocation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct DriverPassengerStats {
    let total: Int = 15
    let coming: Int
    let notComing: Int
    let unknown: Int

    /// Gelmiyorum dışındaki tüm yolcular (geliyorum + belirtmedi).
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
    var showAlwaysLocationGuide = false
    var pendingTripDurationSheetAfterAlways = false
    var selectedTripDurationHours = 2.0

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
        guard locationTracker.canDriverStartTrip else {
            pendingTripDurationSheetAfterAlways = true
            showAlwaysLocationGuide = true
            return
        }
        showTripDurationSheet = true
    }

    func requestDriverAlwaysPermission(locationTracker: LocationTracker) {
        locationTracker.refreshAuthorizationStatus()
        if locationTracker.canDriverStartTrip {
            showAlwaysLocationGuide = false
            return
        }
        pendingTripDurationSheetAfterAlways = true
        showAlwaysLocationGuide = true
    }

    func onDriverLocationAuthorizationUpdated(locationTracker: LocationTracker) {
        locationTracker.refreshAuthorizationStatus()
        if locationTracker.hasWhenInUseAuthorization {
            locationTracker.requestDriverSingleLocation()
        }
        guard locationTracker.canDriverStartTrip else { return }
        showAlwaysLocationGuide = false
        if pendingTripDurationSheetAfterAlways, !showTripDurationSheet {
            pendingTripDurationSheetAfterAlways = false
            showTripDurationSheet = true
        }
    }

    func confirmStartTrip(store: ShuttleStore, session: UserSession, locationTracker: LocationTracker) async {
        guard let profile = session.profile,
              let groupID = profile.groupID else { return }
        let driverName = profile.name

        let hasAlways = await locationTracker.waitForDriverAlwaysAuthorization()
        guard hasAlways else {
            pendingTripDurationSheetAfterAlways = true
            showAlwaysLocationGuide = true
            showError(L10n.alwaysLocationRequiredToStart)
            return
        }

        showAlwaysLocationGuide = false
        pendingTripDurationSheetAfterAlways = false
        showTripDurationSheet = false

        do {
            try await store.startTrip(
                groupID: groupID,
                driverName: driverName,
                durationHours: selectedTripDurationHours,
                locationTracker: locationTracker
            )
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
