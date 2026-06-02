import CoreLocation
import SwiftUI

#if canImport(UIKit)
import UIKit
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

    func configure(session: UserSession) {
        title = session.profile?.groupName ?? L10n.service
        navigationBarStyle = .neonPassenger
        hidesNavigationBar = true
        usesLargeTitle = false
        embedsInNavigationStack = false
    }

    func onAppear(store: ShuttleStore, session: UserSession) {
        configure(session: session)
        let groupID = session.profile?.primaryGroupID ?? ""
        if !groupID.isEmpty {
            store.startListening(groupID: groupID)
        }
    }

    func onTripActiveChanged(wasActive: Bool, isActive: Bool, attendance: AttendanceStatus) {
        if !isActive {
            didPromptAttendanceThisTrip = false
            showTripStartedAttendanceSheet = false
            return
        }
        if isActive && !wasActive {
            presentTripAttendanceSheetIfNeeded(isTripActive: true, attendance: attendance)
        }
    }

    func presentTripAttendanceSheetIfNeeded(isTripActive: Bool, attendance: AttendanceStatus) {
        guard isTripActive, attendance == .unknown, !didPromptAttendanceThisTrip else { return }
        didPromptAttendanceThisTrip = true
        showTripStartedAttendanceSheet = true
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
            showError(error.localizedDescription)
            return
        } catch {
            showError(error.localizedDescription)
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

    func updateAttendance(
        status: AttendanceStatus,
        store: ShuttleStore,
        session: UserSession
    ) async {
        guard let profile = session.profile else { return }
        pendingAttendanceSelection = status
        isUpdatingAttendance = true
        defer {
            isUpdatingAttendance = false
            pendingAttendanceSelection = nil
        }

        do {
            try await store.setAttendance(
                groupID: profile.groupID ?? "",
                memberID: profile.memberID,
                name: profile.name,
                status: status
            )
            showTripStartedAttendanceSheet = false
            showSuccess(L10n.choiceSaved(status.title))
        } catch {
            showError(error.localizedDescription)
        }
    }

    func signOut(store: ShuttleStore, session: UserSession) async {
        store.stopListening()
        await session.signOut()
    }

    func loadSavedPickup(from store: ShuttleStore, session: UserSession) {
        guard let memberID = session.profile?.memberID else { return }
        if draftPickupCoordinate == nil, let pickup = store.morningPickup(for: memberID) {
            draftPickupCoordinate = pickup.coordinate
        }
    }

    func saveMorningPickup(store: ShuttleStore, session: UserSession) async {
        guard let profile = session.profile else { return }
        guard let coordinate = draftPickupCoordinate else {
            showError(L10n.markPickupOnMap)
            return
        }

        isSavingPickup = true
        defer { isSavingPickup = false }

        let groupID = profile.primaryGroupID.isEmpty ? (profile.groupID ?? "") : profile.primaryGroupID
        guard !groupID.isEmpty else {
            showError(L10n.shuttleInfoNotFound)
            return
        }

        do {
            try await store.setMorningPickup(
                groupID: groupID,
                memberID: profile.memberID,
                name: profile.name,
                coordinate: coordinate
            )
            try await store.setAttendance(
                groupID: groupID,
                memberID: profile.memberID,
                name: profile.name,
                status: .coming
            )
            showTripStartedAttendanceSheet = false
            showSuccess(L10n.pickupSavedComing)
        } catch {
            showError(error.localizedDescription)
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
