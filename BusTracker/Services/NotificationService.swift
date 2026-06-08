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

    enum AccessResult: Equatable {
        case granted
        case prompted
        case needsSettings
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

    /// Uygulama açılışında / ön plana gelince: izin yoksa iste, açıksa token senkronize et.
    func ensureNotificationsEnabled(groupID: String?, memberID: String?) async -> AccessResult {
        configure()
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        authorizationStatus = status
        print("📋 [Shuttle Live] Bildirim izni durumu: \(status.rawValue) (0=sorulmadı, 1=reddedildi, 2=açık)")

        switch status {
        case .notDetermined:
            await requestPermissionAndRegister()
            let updated = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            authorizationStatus = updated
            if updated == .authorized || updated == .provisional || updated == .ephemeral {
                isPermissionGranted = true
                await syncTokenIfPossible(groupID: groupID, memberID: memberID)
                return .granted
            }
            if updated == .denied {
                isPermissionGranted = false
                return .needsSettings
            }
            return .prompted

        case .authorized, .provisional, .ephemeral:
            isPermissionGranted = true
            await registerForRemoteNotifications()
            await syncTokenIfPossible(groupID: groupID, memberID: memberID)
            return .granted

        case .denied:
            isPermissionGranted = false
            return .needsSettings

        @unknown default:
            isPermissionGranted = false
            return .needsSettings
        }
    }

    /// Kayıt / giriş sonrası: yalnızca izin zaten verilmişse token kaydet (tekrar popup yok).
    func syncTokenIfAuthorized(groupID: String?, memberID: String?) async {
        let snapshot = await authorizationSnapshot()
        guard snapshot.isEnabled else { return }
        await syncTokenIfPossible(groupID: groupID, memberID: memberID)
    }

    /// Yolcu "Geliyorum" / biniş kaydı: izin yoksa sistem diyaloğu (oturum bayrağına bakmaz).
    func promptForPassengerAction(groupID: String?, memberID: String?) async {
        configure()
        let snapshot = await authorizationSnapshot()
        if snapshot.isEnabled {
            await syncTokenIfPossible(groupID: groupID, memberID: memberID)
            return
        }
        guard snapshot.status == .notDetermined else { return }
        await requestPermissionAndRegister()
        let updated = await authorizationSnapshot()
        if updated.isEnabled {
            await syncTokenIfPossible(groupID: groupID, memberID: memberID)
        }
    }

    /// Geriye dönük uyumluluk — oturumda en fazla bir kez sistem popup'ı.
    func requestPermissionIfNeeded() async {
        guard PermissionPromptSession.mayPromptNotifications else {
            await refreshStatus()
            return
        }
        PermissionPromptSession.markNotificationPromptHandled()
        _ = await ensureNotificationsEnabled(groupID: nil, memberID: nil)
    }

    private func syncTokenIfPossible(groupID: String?, memberID: String?) async {
        guard let groupID, let memberID else { return }
        let trimmed = groupID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        await saveTokenToProfile(groupID: trimmed, memberID: memberID)
    }

    func openSystemSettings() {
#if os(iOS) || os(visionOS)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
#endif
    }

    private func label(for status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: L10n.notificationsNotRequested
        case .denied: L10n.notificationsOffSystemSettings
        case .authorized: L10n.notificationsOn
        case .provisional: L10n.notificationsOnTemporary
        case .ephemeral: L10n.notificationsOn
        @unknown default: L10n.notificationsUnknown
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
        let type = Self.notificationType(from: notification.request.content.userInfo)
        if type == SparseModeSuggestion.intentType {
            return []
        }
        return [.banner, .sound, .list]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        await MainActor.run {
            PushNotificationRouter.handle(userInfo: userInfo)
        }
    }
}

extension NotificationService {
    /// Servis çağrısı — korna sesi (bundle: approach_tink.caf).
    static let approachSoundName = "approach_tink.caf"

    nonisolated static func notificationType(from userInfo: [AnyHashable: Any]) -> String? {
        if let type = userInfo["type"] as? String { return type }
        if let gcm = userInfo["gcm.notification.type"] as? String { return gcm }
        return nil
    }

    nonisolated static func isShuttleCallNotification(_ userInfo: [AnyHashable: Any]) -> Bool {
        notificationType(from: userInfo) == "driver_approaching"
    }
}

/// `trip_started` bildirimine basınca yolcu harita sekmesine gider (yoklama sheet'i ayrı kurallarla).
@MainActor
enum PushNotificationRouter {
    static let openPassengerMapNotification = Notification.Name("PushNotificationRouter.openPassengerMap")
    static let openSparseModeSheetNotification = Notification.Name("PushNotificationRouter.openSparseModeSheet")

    private static var pendingOpenPassengerMap = false
    private static var pendingOpenSparseModeSheet = false

    static func handle(userInfo: [AnyHashable: Any]) {
        let type = NotificationService.notificationType(from: userInfo)
        switch type {
        case "trip_started", "passenger_boarded", "canonical_route_ready":
            pendingOpenPassengerMap = true
            NotificationCenter.default.post(name: openPassengerMapNotification, object: nil)
        case SparseModeSuggestionNotifier.notificationType, "open_holiday_mode":
            pendingOpenSparseModeSheet = true
            NotificationCenter.default.post(name: openSparseModeSheetNotification, object: nil)
        default:
            break
        }
    }

    static func consumePendingOpenPassengerMap() -> Bool {
        guard pendingOpenPassengerMap else { return false }
        pendingOpenPassengerMap = false
        return true
    }

    static func consumePendingOpenSparseModeSheet() -> Bool {
        guard pendingOpenSparseModeSheet else { return false }
        pendingOpenSparseModeSheet = false
        return true
    }
}

extension NotificationService: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        // Ensure we received a valid token and update stored token if needed
        guard let token = fcmToken else { return }
        // Optionally, you could compare with Messaging.messaging().fcmToken, but saving on callback is fine
        Task { @MainActor in
            guard let profile = UserSession.shared.profile else { return }
            let groupID = profile.primaryGroupID.isEmpty
                ? (profile.groupID ?? "")
                : profile.primaryGroupID
            guard !groupID.isEmpty,
                  let token = fcmToken ?? Messaging.messaging().fcmToken
            else { return }
            await self.saveTokenToProfile(token: token, groupID: groupID, memberID: profile.memberID)
        }
    }
}

#if os(iOS) || os(visionOS)
import UIKit
#endif
