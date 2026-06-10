import Foundation

struct DriverSubscriptionInfo: Equatable {
    static let expiringSoonDays = 7

    var startDate: Date?
    var endDate: Date?

    var isActive: Bool {
        guard let endDate else { return false }
        let today = HolidayMode.calendar.startOfDay(for: Date())
        return HolidayMode.calendar.startOfDay(for: endDate) >= today
    }

    var daysRemaining: Int? {
        guard isActive, let endDate else { return nil }
        let today = HolidayMode.calendar.startOfDay(for: Date())
        let end = HolidayMode.calendar.startOfDay(for: endDate)
        return HolidayMode.calendar.dateComponents([.day], from: today, to: end).day
    }

    var isExpiringSoon: Bool {
        guard let daysRemaining else { return false }
        return daysRemaining >= 0 && daysRemaining <= Self.expiringSoonDays
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
