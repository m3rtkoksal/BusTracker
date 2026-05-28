import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseMessaging
import Foundation
import UserNotifications

@MainActor
@Observable
final class NotificationService: NSObject {
    static let shared = NotificationService()

    private(set) var isPermissionGranted = false
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private var didConfigure = false

    struct AuthorizationSnapshot {
        let status: UNAuthorizationStatus
        let label: String
        let isEnabled: Bool
    }

    private override init() {
        super.init()
    }

    func configure() {
        guard !didConfigure else { return }
        guard FirebaseApp.app() != nil else {
            print("⚠️ [BusTracker] NotificationService.configure — Firebase henüz yok")
            return
        }
        didConfigure = true
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
    }

    /// Auth hazır olduktan sonra AppDelegate'ten çağrılır.
    func setAPNSToken(_ deviceToken: Data) {
        guard FirebaseApp.app() != nil else { return }
        if Messaging.messaging().apnsToken != deviceToken {
            Messaging.messaging().apnsToken = deviceToken
        }
    }

    func requestPermissionAndRegister() async {
        configure()
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            isPermissionGranted = granted
            if granted {
                await registerForRemoteNotifications()
            }
        } catch {
            isPermissionGranted = false
        }
    }

    func authorizationSnapshot() async -> AuthorizationSnapshot {
        configure()
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        authorizationStatus = status
        isPermissionGranted = status == .authorized || status == .provisional || status == .ephemeral
        return AuthorizationSnapshot(
            status: status,
            label: label(for: status),
            isEnabled: isPermissionGranted
        )
    }

    func refreshStatus() async {
        _ = await authorizationSnapshot()
    }

    /// Daha önce sorulmadıysa sistem bildirim diyaloğunu gösterir.
    func requestPermissionIfNeeded() async {
        configure()
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        print("📋 [Shuttle Live] Bildirim izni durumu: \(status.rawValue) (0=sorulmadı, 1=reddedildi, 2=açık)")
        switch status {
        case .notDetermined:
            await requestPermissionAndRegister()
        case .authorized, .provisional, .ephemeral:
            isPermissionGranted = true
            authorizationStatus = status
            await registerForRemoteNotifications()
        default:
            isPermissionGranted = false
            authorizationStatus = status
            print("📋 [Shuttle Live] Bildirim daha önce reddedilmiş — Ayarlar'dan açılabilir")
        }
    }

    func openSystemSettings() {
#if os(iOS) || os(visionOS)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
#endif
    }

    private func label(for status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: "Henüz izin istenmedi"
        case .denied: "Kapalı — sistem ayarlarından açın"
        case .authorized: "Açık"
        case .provisional: "Açık (geçici)"
        case .ephemeral: "Açık"
        @unknown default: "Bilinmiyor"
        }
    }

    @MainActor
    private func registerForRemoteNotifications() async {
#if os(iOS) || os(visionOS)
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
#endif
    }

    func saveTokenToProfile(token: String, groupID: String, memberID: String) async {
        guard let userID = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()
        try? await db.collection("users").document(userID).setData([
            "fcmToken": token,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)

        try? await db.collection("groups").document(groupID)
            .collection("members").document(memberID)
            .setData([
                "fcmToken": token,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
    }

    func saveTokenToProfile(groupID: String, memberID: String) async {
        guard let token = Messaging.messaging().fcmToken else { return }
        await saveTokenToProfile(token: token, groupID: groupID, memberID: memberID)
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

extension NotificationService: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        // Ensure we received a valid token and update stored token if needed
        guard let token = fcmToken else { return }
        // Optionally, you could compare with Messaging.messaging().fcmToken, but saving on callback is fine
        Task { @MainActor in
            // You might want to persist the token immediately to Firestore under the current user/group
            if let profile = UserSession.shared.profile {
                if let groupID = profile.groupID as? String, let memberID = profile.memberID as? String {
                    if let token = fcmToken ?? Messaging.messaging().fcmToken {
                        await self.saveTokenToProfile(token: token, groupID: groupID, memberID: memberID)
                    }
                }
            }
        }
    }
}

#if os(iOS) || os(visionOS)
import UIKit
#endif
