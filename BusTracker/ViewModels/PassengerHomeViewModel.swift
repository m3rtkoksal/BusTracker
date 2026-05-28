import CoreLocation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

@MainActor
@Observable
final class PassengerHomeViewModel: BaseViewModel {
    var showTripStartedBanner = false
    var isUpdatingAttendance = false
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

    func onTripActiveChanged(wasActive: Bool, isActive: Bool) {
        if isActive && !wasActive {
            showTripStartedBanner = true
            showInfo("Servis yola çıktı! Gelecek misiniz?", title: "Servis Başladı")
        }
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

    /// Kullanıcının hesabını siler.
    /// Güvenlik için yeniden telefon doğrulaması (OTP) yapması önerilir.
    func deleteAccount(store: ShuttleStore, session: UserSession, authService: AuthService) async {
        guard let profile = session.profile else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            // 1. Kullanıcı verilerini sil (Firestore)
            try await store.deleteUserData(profile: profile)

            // 2. Firebase Auth kullanıcısını sil (önce re-auth önerilir)
            try await authService.deleteCurrentUser()

            // 3. Yerel oturumu temizle
            store.stopListening()
            await session.signOut()

            showSuccess("Hesabınız başarıyla silindi.")
        } catch {
            showError("Hesap silinirken bir hata oluştu: \(error.localizedDescription)")
        }
    }

    func updateAttendance(
        status: AttendanceStatus,
        store: ShuttleStore,
        session: UserSession
    ) async {
        guard let profile = session.profile else { return }
        isUpdatingAttendance = true
        defer { isUpdatingAttendance = false }

        do {
            try await store.setAttendance(
                groupID: profile.groupID ?? "",
                memberID: profile.memberID,
                name: profile.name,
                status: status
            )
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
