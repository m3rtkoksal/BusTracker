import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import Foundation
import UserNotifications

@MainActor
@Observable
final class NotificationService: NSObject {
    static let shared = NotificationService()

    private(set) var isPermissionGranted = false
    private var didConfigure = false

    private override init() {
        super.init()
    }

    func configure() {
        guard !didConfigure else { return }
        didConfigure = true
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
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

    @MainActor
    private func registerForRemoteNotifications() async {
#if os(iOS) || os(visionOS)
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
#endif
    }

    func saveTokenToProfile(groupID: String, memberID: String) async {
        guard let token = Messaging.messaging().fcmToken,
              let userID = Auth.auth().currentUser?.uid else { return }

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
        guard fcmToken != nil else { return }
        Task { @MainActor in
            if let profile = UserSession.shared.profile {
                await self.saveTokenToProfile(groupID: profile.groupID, memberID: profile.memberID)
            }
        }
    }
}

#if os(iOS) || os(visionOS)
import UIKit
#endif
