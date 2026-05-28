import CoreLocation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct DriverPassengerStats {
    let total: Int = 15          // Sabit maksimum kapasite
    let coming: Int
    let notComing: Int
    let unknown: Int

    var comingProgress: Double {
        guard total > 0 else { return 0 }
        return Double(coming) / Double(total)
    }
}

@MainActor
@Observable
final class DriverHomeViewModel: BaseViewModel {
    func configure(session: UserSession) {
        title = session.profile?.groupName ?? "Servis"
        navigationBarStyle = .neonDriver
        hidesNavigationBar = true
        usesLargeTitle = false
    }

    func passengerStats(from members: [ShuttleMember]) -> DriverPassengerStats {
        let passengers = members.filter { $0.role == .passenger }
        return DriverPassengerStats(
            coming: passengers.filter { $0.attendance == .coming }.count,
            notComing: passengers.filter { $0.attendance == .notComing }.count,
            unknown: passengers.filter { $0.attendance == .unknown }.count
        )
    }

    func onAppear(store: ShuttleStore, session: UserSession, locationTracker: LocationTracker) {
        configure(session: session)
        locationTracker.requestPermission()
        if let groupID = session.profile?.groupID {
            store.startListening(groupID: groupID)
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
            message: "Hesabınızı ve tüm verilerinizi (profil, servis yönetimi, yolcu kayıtları vb.) kalıcı olarak silmek istediğinize emin misiniz? Bu işlem geri alınamaz.",
            confirmTitle: "Hesabı Kalıcı Olarak Sil",
            destructive: true,
            onConfirm: onConfirm
        )
    }

    /// Kullanıcının hesabını siler (sürücü).
    func deleteAccount(store: ShuttleStore, session: UserSession, authService: AuthService) async {
        guard let profile = session.profile else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            // 1. Kullanıcı ve ilgili verileri sil
            try await store.deleteUserData(profile: profile)

            // 2. Firebase Auth kullanıcısını sil
            try await authService.deleteCurrentUser()

            // 3. Oturumu temizle
            if store.isTripActive {
                await store.stopTrip(groupID: profile.groupID ?? "", driverName: profile.name, locationTracker: LocationTracker())
            }
            store.stopListening()
            await session.signOut()

            showSuccess("Hesabınız başarıyla silindi.")
        } catch {
            showError("Hesap silinirken bir hata oluştu: \(error.localizedDescription)")
        }
    }

    func toggleTrip(store: ShuttleStore, session: UserSession, locationTracker: LocationTracker) async {
        guard let profile = session.profile,
              let groupID = profile.groupID else { return }
        let driverName = profile.name

        if store.isTripActive {
            await store.stopTrip(groupID: groupID, driverName: driverName, locationTracker: locationTracker)
        } else {
            locationTracker.requestBackgroundPermission()
            do {
                try await store.startTrip(
                    groupID: groupID,
                    driverName: driverName,
                    locationTracker: locationTracker
                )
                showSuccess("Servis başlatıldı. Yolcular bilgilendirildi.")
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    func signOut(store: ShuttleStore, session: UserSession, locationTracker: LocationTracker) async {
        if store.isTripActive,
           let profile = session.profile,
           let groupID = profile.groupID {
            let driverName = profile.name
            await store.stopTrip(groupID: groupID, driverName: driverName, locationTracker: locationTracker)
        }
        store.stopListening()
        await session.signOut()
    }

    func copyGroupCode(_ code: String) {
#if os(iOS) || os(visionOS)
        UIPasteboard.general.string = code
        showSuccess("Servis kodu kopyalandı.")
#endif
    }
}

