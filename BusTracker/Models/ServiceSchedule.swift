import Foundation

/// Servis seansı: Sabah veya Akşam
enum ServiceSession: String, Codable, Equatable {
    case morning = "am"
    case evening = "pm"
    
    var displayName: String {
        switch self {
        case .morning: return "Sabah"
        case .evening: return "Akşam"
        }
    }
    
    var icon: String {
        switch self {
        case .morning: return "☀️"
        case .evening: return "🌙"
        }
    }
}

/// Yaklaşan bir servis: tarih + seans
struct UpcomingService: Equatable {
    let date: Date
    let session: ServiceSession
    
    var dateKey: String {
        let base = HolidayMode.dateKey(from: date)
        return "\(base)-\(session.rawValue)"
    }
    
    var dayName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date).capitalized
    }
    
    var displayDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }
    
    /// "Pazartesi Sabah" veya "Salı Akşam" gibi
    var fullDisplayName: String {
        "\(dayName) \(session.displayName)"
    }
    
    /// "Bugün Sabah", "Yarın Akşam", "Pazartesi Sabah" gibi
    func relativeDisplayName(from reference: Date = Date()) -> String {
        let cal = HolidayMode.calendar
        let refDay = cal.startOfDay(for: reference)
        let serviceDay = cal.startOfDay(for: date)
        
        let dayDiff = cal.dateComponents([.day], from: refDay, to: serviceDay).day ?? 0
        
        let dayPart: String
        switch dayDiff {
        case 0: dayPart = "Bugün"
        case 1: dayPart = "Yarın"
        default: dayPart = dayName
        }
        
        return "\(dayPart) \(session.displayName)"
    }
}

/// Servis zamanlama hesaplamaları
enum ServiceSchedule {
    
    // MARK: - Sabit Saatler
    
    /// Sabah servisi bitiş saati (bu saatten sonra sabah servisi geçmiş sayılır)
    static let morningEndHour = 10
    
    /// Akşam servisi başlangıç saati
    static let eveningStartHour = 16
    
    /// Akşam servisi bitiş saati (bu saatten sonra akşam servisi geçmiş sayılır)
    static let eveningEndHour = 20
    
    // MARK: - Yolcu: Sonraki 2 Servis
    
    /// Yolcunun göreceği sonraki 2 servisi hesaplar
    /// - Parameter reference: Şu anki zaman (test için override edilebilir)
    /// - Returns: Sonraki 2 servis (her zaman 2 eleman döner)
    static func nextTwoServices(from reference: Date = Date()) -> [UpcomingService] {
        let cal = HolidayMode.calendar
        let hour = cal.component(.hour, from: reference)
        let weekday = cal.component(.weekday, from: reference)
        
        // Cumartesi (7) veya Pazar (1) - hafta sonu
        let isWeekend = weekday == 1 || weekday == 7
        
        if isWeekend {
            // Hafta sonu: Pazartesi sabah + Pazartesi akşam
            let monday = nextWeekday(from: reference)
            return [
                UpcomingService(date: monday, session: .morning),
                UpcomingService(date: monday, session: .evening)
            ]
        }
        
        let today = cal.startOfDay(for: reference)
        
        if hour < morningEndHour {
            // 00:00 - 09:59: Bugün sabah + Bugün akşam
            return [
                UpcomingService(date: today, session: .morning),
                UpcomingService(date: today, session: .evening)
            ]
        } else if hour < eveningEndHour {
            // 10:00 - 19:59: Bugün akşam + Sonraki iş günü sabah
            let nextWorkday = nextWeekday(from: reference, afterToday: true)
            return [
                UpcomingService(date: today, session: .evening),
                UpcomingService(date: nextWorkday, session: .morning)
            ]
        } else {
            // 20:00 - 23:59: Sonraki iş günü sabah + akşam
            let nextWorkday = nextWeekday(from: reference, afterToday: true)
            return [
                UpcomingService(date: nextWorkday, session: .morning),
                UpcomingService(date: nextWorkday, session: .evening)
            ]
        }
    }
    
    // MARK: - Sürücü: Hangi Servis Modunda?
    
    /// Sürücünün göreceği servis seansını hesaplar
    /// - Parameter reference: Şu anki zaman
    /// - Returns: (tarih, seans) tuple'ı
    static func currentDriverSession(from reference: Date = Date()) -> UpcomingService {
        let cal = HolidayMode.calendar
        let hour = cal.component(.hour, from: reference)
        let weekday = cal.component(.weekday, from: reference)
        
        // Cumartesi (7) veya Pazar (1) - hafta sonu
        let isWeekend = weekday == 1 || weekday == 7
        
        if isWeekend {
            // Hafta sonu: Pazartesi sabah
            let monday = nextWeekday(from: reference)
            return UpcomingService(date: monday, session: .morning)
        }
        
        let today = cal.startOfDay(for: reference)
        
        if hour < morningEndHour {
            // 00:00 - 09:59: Sabah servisi
            return UpcomingService(date: today, session: .morning)
        } else if hour < eveningEndHour {
            // 10:00 - 19:59: Akşam servisi
            return UpcomingService(date: today, session: .evening)
        } else {
            // 20:00 - 23:59: Sonraki iş günü sabah
            let nextWorkday = nextWeekday(from: reference, afterToday: true)
            return UpcomingService(date: nextWorkday, session: .morning)
        }
    }
    
    // MARK: - Yardımcı Fonksiyonlar
    
    /// Sonraki hafta içi günü bulur
    /// - Parameters:
    ///   - reference: Başlangıç tarihi
    ///   - afterToday: true ise bugünü atlar (yarından başlar)
    /// - Returns: Sonraki hafta içi gün
    private static func nextWeekday(from reference: Date, afterToday: Bool = false) -> Date {
        let cal = HolidayMode.calendar
        var date = cal.startOfDay(for: reference)
        
        if afterToday {
            date = cal.date(byAdding: .day, value: 1, to: date) ?? date
        }
        
        // Hafta sonu ise Pazartesi'ye atla
        var weekday = cal.component(.weekday, from: date)
        while weekday == 1 || weekday == 7 { // Pazar(1) veya Cumartesi(7)
            date = cal.date(byAdding: .day, value: 1, to: date) ?? date
            weekday = cal.component(.weekday, from: date)
        }
        
        return date
    }
    
    // MARK: - DateKey Yardımcıları
    
    /// DateKey'den tarih ve seans çıkarır
    /// - Parameter dateKey: "2026-06-09-am" formatında key
    /// - Returns: (date, session) tuple'ı veya nil
    static func parse(dateKey: String) -> (date: Date, session: ServiceSession)? {
        let parts = dateKey.split(separator: "-")
        guard parts.count == 4,
              let session = ServiceSession(rawValue: String(parts[3])) else {
            return nil
        }
        
        let baseDateKey = parts[0...2].joined(separator: "-")
        guard let date = HolidayMode.date(fromKey: baseDateKey) else {
            return nil
        }
        
        return (date, session)
    }
    
    /// Bugünün sabah ve akşam dateKey'lerini döndürür
    static func todayDateKeys(from reference: Date = Date()) -> (morning: String, evening: String) {
        let cal = HolidayMode.calendar
        let today = cal.startOfDay(for: reference)
        let base = HolidayMode.dateKey(from: today)
        return ("\(base)-am", "\(base)-pm")
    }
}
