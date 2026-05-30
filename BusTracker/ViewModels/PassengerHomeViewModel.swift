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
        title = session.profile?.groupName ?? "Servis"
        navigationBarStyle = .neonPassenger
        hidesNavigationBar = true
        usesLargeTitle = false
        embedsInNavigationStack = false
    }

    func onAppear(store: ShuttleStore, session: UserSession) {
        configure(session: session)
        if let groupID = session.profile?.groupID {
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
            title: "Çıkış Yap",
            message: "Çıkış yapmak istediğinize emin misiniz?",
            confirmTitle: "Çıkış Yap",
            destructive: true,
            onConfirm: onConfirm
        )
    }

    // MARK: - Hesap Silme (App Store 5.1.1(v) için gerekli)
    func requestDeleteAccount(onConfirm: @escaping () -> Void) {
        showConfirm(
            title: "Hesabı Sil",
            message: "Hesabınızı ve tüm verilerinizi (profil, biniş noktaları, katılım kayıtları vb.) kalıcı olarak silmek istediğinize emin misiniz? Bu işlem geri alınamaz.",
            confirmTitle: "Hesabı Kalıcı Olarak Sil",
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
            showSuccess("Hesabınız başarıyla silindi.")
        } else {
            showError("Hesap silinirken bir hata oluştu. Lütfen tekrar deneyin.")
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
            showSuccess("Seçiminiz kaydedildi: \(status.title)")
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

    func copyGroupCode(_ code: String) {
        UIPasteboard.general.string = code
        showSuccess("Servis kodu kopyalandı.")
    }

    func saveMorningPickup(store: ShuttleStore, session: UserSession) async {
        guard let profile = session.profile else { return }
        guard let coordinate = draftPickupCoordinate else {
            showError("Haritada sabah biniş noktanızı işaretleyin.")
            return
        }

        isSavingPickup = true
        defer { isSavingPickup = false }

        do {
            try await store.setMorningPickup(
                groupID: profile.groupID ?? "",
                memberID: profile.memberID,
                name: profile.name,
                coordinate: coordinate
            )
            showSuccess("Sabah biniş noktanız kaydedildi.")
        } catch {
            showError(error.localizedDescription)
        }
    }
}
