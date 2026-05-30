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
            title: "Çıkış Yap",
            message: "Çıkış yapmak istediğinize emin misiniz?",
            confirmTitle: "Çıkış Yap",
            destructive: true,
            onConfirm: onConfirm
        )
    }

    func requestDeleteAccount(onConfirm: @escaping () -> Void) {
        showConfirm(
            title: "Hesabı Sil",
            message: "Hesabınızı ve tüm verilerinizi kalıcı olarak silmek istediğinize emin misiniz? Bu işlem geri alınamaz.",
            confirmTitle: "Hesabı Kalıcı Olarak Sil",
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
            showSuccess("Hesabınız başarıyla silindi.")
        } else {
            showError("Hesap silinirken bir hata oluştu. Lütfen tekrar deneyin.")
        }
    }

    func handleTripControlTap(store: ShuttleStore, session: UserSession, locationTracker: LocationTracker) async {
        guard let profile = session.profile,
              let groupID = profile.groupID else { return }
        let driverName = profile.name

        if store.isTripActive {
            await store.stopTrip(groupID: groupID, driverName: driverName, locationTracker: locationTracker)
            showSuccess("Servis durduruldu.")
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
            showError(
                "Servisi başlatmak için \"Her zaman\" konum izni zorunludur. Ayarlar'dan izin verin."
            )
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
            let hoursLabel = selectedTripDurationHours == floor(selectedTripDurationHours)
                ? "\(Int(selectedTripDurationHours)) saat"
                : "\(selectedTripDurationHours) saat"
            showSuccess("Servis başlatıldı. \(hoursLabel) sonra otomatik duracak.")
        } catch {
            showError(error.localizedDescription)
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

    func copyGroupCode(_ code: String) {
#if os(iOS) || os(visionOS)
        UIPasteboard.general.string = code
        showSuccess("Servis kodu kopyalandı.")
#endif
    }
}
