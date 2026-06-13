import Foundation

struct DriverSubscriptionInfo: Equatable {
    static let expiringSoonDays = ShuttlePoolConfig.expiringSoonDays
    static let gracePeriodDays = ShuttlePoolConfig.gracePeriodDays

    var startDate: Date?
    var endDate: Date?

    /// Paid period still within subscription end date.
    var isInPaidPeriod: Bool {
        if ShuttlePoolConfig.pilotModeEnforcementDisabled { return true }
        guard let endDate else { return false }
        let today = HolidayMode.calendar.startOfDay(for: Date())
        return HolidayMode.calendar.startOfDay(for: endDate) >= today
    }

    /// Service stays on until grace period after subscription end (default +7 days).
    var isServiceOperational: Bool {
        if ShuttlePoolConfig.pilotModeEnforcementDisabled { return true }
        guard let endDate else { return false }
        let today = HolidayMode.calendar.startOfDay(for: Date())
        let graceEnd = HolidayMode.calendar.date(
            byAdding: .day,
            value: Self.gracePeriodDays,
            to: HolidayMode.calendar.startOfDay(for: endDate)
        ) ?? endDate
        return today <= graceEnd
    }

    var isActive: Bool { isServiceOperational }

    var daysRemaining: Int? {
        guard isInPaidPeriod, let endDate else { return nil }
        let today = HolidayMode.calendar.startOfDay(for: Date())
        let end = HolidayMode.calendar.startOfDay(for: endDate)
        return HolidayMode.calendar.dateComponents([.day], from: today, to: end).day
    }

    var isExpiringSoon: Bool {
        if ShuttlePoolConfig.pilotModeEnforcementDisabled { return false }
        guard let daysRemaining else { return false }
        return daysRemaining >= 0 && daysRemaining <= Self.expiringSoonDays
    }

    var isInGracePeriod: Bool {
        if ShuttlePoolConfig.pilotModeEnforcementDisabled { return false }
        guard let endDate else { return false }
        return !isInPaidPeriod && isServiceOperational
    }

    static let empty = DriverSubscriptionInfo(startDate: nil, endDate: nil)
}

enum DriverSubscriptionDisplay {
    @MainActor
    static func formatDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: LanguageManager.shared.language.rawValue)
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }
}
