import Foundation
import UserNotifications

/// Seyrek kullanım önerisi — yerel bildirim (sheet ayrı gösterilir).
@MainActor
enum SparseModeSuggestionNotifier {
    static let notificationType = SparseModeSuggestion.intentType
    private static let requestIdentifier = "sparse_mode_suggestion"

    static func postNotificationIfNeeded(memberID: String, prompt: SparseModeSuggestion.Prompt) async {
        guard SparseModeSuggestion.shouldSendNotification(memberID: memberID) else { return }

        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
            || settings.authorizationStatus == .ephemeral
        else { return }

        await scheduleNotification(comingDays: prompt.comingDays)
        SparseModeSuggestion.markNotificationSent(memberID: memberID)
    }

    private static func scheduleNotification(comingDays: Int) async {
        let content = UNMutableNotificationContent()
        content.title = L10n.sparseModeSuggestionTitle
        content.body = L10n.sparseModeSuggestionBody(comingDays: comingDays)
        content.userInfo = ["type": notificationType]
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(
            identifier: requestIdentifier,
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
