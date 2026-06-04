import Foundation

/// Seyrek servis modu (UI: Tatil Modu): Bitiş tarihine kadar her takvim günü ayrı kayıt.
/// Seçim yok → sürücüde gelmiyorum; servise binecek gün Geliyorum seçilir (yalnızca o gün).
enum HolidayMode {
    static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "tr_TR")
        cal.timeZone = TimeZone(identifier: "Europe/Istanbul") ?? .current
        return cal
    }

    static func dateKey(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func date(fromKey key: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: key)
    }

    /// Tatil bitiş günü dahil; ertesi gün tatil biter.
    static func isActive(endDateKey: String, reference: Date = Date()) -> Bool {
        guard let end = date(fromKey: endDateKey) else { return false }
        let refDay = calendar.startOfDay(for: reference)
        let endDay = calendar.startOfDay(for: end)
        return refDay <= endDay
    }

    static func displayDate(endDateKey: String) -> String? {
        guard let date = date(fromKey: endDateKey) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }

    static func tomorrowDateKey(from reference: Date = Date()) -> String {
        let day = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: reference)) ?? reference
        return dateKey(from: day)
    }

    /// Bugünün tarih anahtarı (yolcu seçimi + sürücü listesi aynı gün belgesi).
    static func attendancePlanningDateKey(holidayModeActive: Bool, reference: Date = Date()) -> String {
        dateKey(from: reference)
    }

    static func displayDateLabel(dateKey: String) -> String {
        guard let date = date(fromKey: dateKey) else { return dateKey }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }
}

extension ShuttleMember {
    var isHolidayModeActive: Bool {
        guard let key = holidayModeEndDate else { return false }
        return HolidayMode.isActive(endDateKey: key)
    }

    /// Mod açıkken: bu gün için açık Geliyorum geçerli; seçim yoksa gelmiyorum (günlük kayıt).
    var effectiveAttendance: AttendanceStatus {
        guard isHolidayModeActive else { return attendance }
        switch attendance {
        case .coming: return .coming
        case .notComing: return .notComing
        case .unknown: return .notComing
        }
    }
}
