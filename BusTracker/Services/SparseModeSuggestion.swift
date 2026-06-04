import Foundation

/// Seyrek servis kullanımı — sheet + bildirim kuralları.
enum SparseModeSuggestion {
    static let intentType = "sparse_mode_suggestion"

    private static let prefsSuite = "bustracker_sparse_mode_suggestion"
    private static let windowDays = 30
    private static let maxComingInMonth = 3
    private static let minExplicitInMonth = 3
    private static let notificationCooldownDays = 90

    struct Prompt {
        let comingDays: Int
    }

    static func evaluate(
        groupID: String,
        memberID: String,
        holidayModeActive: Bool
    ) async -> Prompt? {
        guard !memberID.isEmpty, !holidayModeActive else { return nil }

        let month = await AttendanceUsageTracker.statsForWindowWithFirestoreSync(
            groupID: groupID,
            memberID: memberID,
            windowDays: windowDays
        )
        guard isEligible(month: month) else { return nil }
        return Prompt(comingDays: month.coming)
    }

    static func isEligible(month: AttendanceUsageTracker.WindowStats) -> Bool {
        guard month.coming <= maxComingInMonth else { return false }
        guard month.explicit >= minExplicitInMonth else { return false }
        guard month.notComing >= month.coming || month.notComing >= minExplicitInMonth else { return false }
        return true
    }

    static func shouldSendNotification(memberID: String) -> Bool {
        let sentAt = UserDefaults.standard.double(forKey: notificationSentKey(memberID))
        guard sentAt > 0 else { return true }
        let elapsed = Date().timeIntervalSince1970 - sentAt
        return elapsed >= Double(notificationCooldownDays * 24 * 3600)
    }

    static func markNotificationSent(memberID: String) {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: notificationSentKey(memberID))
    }

    static func dateKeysForWindow(_ windowDays: Int) -> [String] {
        let endKey = HolidayMode.dateKey(from: Date())
        guard var endDate = HolidayMode.date(fromKey: endKey) else { return [] }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Istanbul") ?? .current
        cal.locale = Locale(identifier: "tr_TR")
        endDate = cal.startOfDay(for: endDate)
        var keys: [String] = []
        for _ in 0..<windowDays {
            keys.insert(HolidayMode.dateKey(from: endDate), at: 0)
            guard let prev = cal.date(byAdding: .day, value: -1, to: endDate) else { break }
            endDate = prev
        }
        return keys
    }

    private static func notificationSentKey(_ memberID: String) -> String { "notification_sent_\(memberID)" }
}
