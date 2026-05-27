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
