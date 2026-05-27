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

