import CoreLocation
import Foundation

enum PassengerWeatherTiming: Equatable {
    case todayMorning
    case tomorrowMorning
    case weekdayMorning(String)
}

struct PassengerWeatherAdvisoryContext: Equatable {
    let targetMorning: Date
    let timing: PassengerWeatherTiming

    var targetMorningKey: String {
        HolidayMode.dateKey(from: targetMorning)
    }
}

struct PassengerWeatherCardModel: Equatable {
    let placeName: String
    let temperatureC: Int
    /// Push bildirimiyle aynı tarz giyim önerisi.
    let advice: String
    let emoji: String
    let timing: PassengerWeatherTiming

    var contextLine: String {
        L10n.weatherContextMorning(timing: timing, placeName: placeName, temperature: temperatureC)
    }
}

enum PassengerWeatherService {
    private static let openMeteoURL = URL(string: "https://api.open-meteo.com/v1/forecast")!
    private static let nominatimURL = URL(string: "https://nominatim.openstreetmap.org/reverse")!
    private static let cacheKeyPrefix = "passengerWeather."
    private static let neighborhoodAddressKeys = [
        "neighbourhood",
        "suburb",
        "quarter",
        "hamlet",
        "residential",
        "city_district",
    ]
    private static let coldTempC = 6.0
    private static let hotTempC = 31.0
    private static let wetMm = 0.15

    /// Sabah servisine çıkmadan önce öneri: akşam 20:00 – ertesi gün 07:00.
    private static let advisoryEveningStartHour = 20
    private static let advisoryMorningEndHour = 7
    private static let morningForecastHour = 7

    private struct WeatherCachePayload: Codable {
        let latitude: Double
        let longitude: Double
        let placeName: String
        let tempC: Double
        let precipitation: Double
        let rain: Double
        let targetMorningKey: String
        let timing: String
        let weekdayName: String?
        let fetchedAt: Date
    }

    /// Giyim önerisi yalnızca akşam (20:00+) veya sabah servisten önce (07:00 öncesi) gösterilir.
    static func advisoryContext(from reference: Date = Date()) -> PassengerWeatherAdvisoryContext? {
        let cal = HolidayMode.calendar
        let hour = cal.component(.hour, from: reference)
        guard hour < advisoryMorningEndHour || hour >= advisoryEveningStartHour else {
            return nil
        }

        let weekday = cal.component(.weekday, from: reference)
        let isWeekend = weekday == 1 || weekday == 7
        let targetMorning: Date

        if hour < advisoryMorningEndHour {
            targetMorning = isWeekend
                ? nextWorkdayStart(from: reference)
                : cal.startOfDay(for: reference)
        } else {
            targetMorning = nextWorkdayStart(from: reference, afterToday: true)
        }

        return PassengerWeatherAdvisoryContext(
            targetMorning: targetMorning,
            timing: timingLabel(for: targetMorning, reference: reference)
        )
    }

    @MainActor
    static func cachedModel(
        for coordinate: CLLocationCoordinate2D,
        advisory: PassengerWeatherAdvisoryContext
    ) -> PassengerWeatherCardModel? {
        guard isValidCoordinate(coordinate),
              let entry = cachedEntry(for: coordinate, targetMorningKey: advisory.targetMorningKey)
        else { return nil }
        return model(from: entry)
    }

    @MainActor
    static func load(
        for coordinate: CLLocationCoordinate2D,
        advisory: PassengerWeatherAdvisoryContext
    ) async -> PassengerWeatherCardModel? {
        guard isValidCoordinate(coordinate) else { return nil }

        if let entry = cachedEntry(for: coordinate, targetMorningKey: advisory.targetMorningKey) {
            return model(from: entry)
        }

        async let weatherTask = fetchMorningForecast(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            targetMorning: advisory.targetMorning,
            forecastHour: morningForecastHour
        )
        async let placeTask = resolvePlaceName(for: coordinate)
        guard let weather = await weatherTask else { return nil }

        let placeName = await placeTask
        let entry = WeatherCachePayload(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            placeName: placeName,
            tempC: weather.tempC,
            precipitation: weather.precipitation,
            rain: weather.rain,
            targetMorningKey: advisory.targetMorningKey,
            timing: timingStorageKey(advisory.timing),
            weekdayName: weekdayStorageName(advisory.timing),
            fetchedAt: Date()
        )
        saveCache(entry, for: coordinate)
        return model(from: entry)
    }

    private static func cacheStorageKey(for coordinate: CLLocationCoordinate2D, targetMorningKey: String) -> String {
        cacheKeyPrefix + targetMorningKey + ".h\(morningForecastHour)."
            + String(format: "%.4f,%.4f", coordinate.latitude, coordinate.longitude)
    }

    private static func cachedEntry(
        for coordinate: CLLocationCoordinate2D,
        targetMorningKey: String
    ) -> WeatherCachePayload? {
        let key = cacheStorageKey(for: coordinate, targetMorningKey: targetMorningKey)
        guard let data = UserDefaults.standard.data(forKey: key),
              let entry = try? JSONDecoder().decode(WeatherCachePayload.self, from: data),
              entry.targetMorningKey == targetMorningKey
        else {
            return nil
        }
        return entry
    }

    private static func saveCache(_ entry: WeatherCachePayload, for coordinate: CLLocationCoordinate2D) {
        guard let data = try? JSONEncoder().encode(entry) else { return }
        let key = cacheStorageKey(for: coordinate, targetMorningKey: entry.targetMorningKey)
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func model(from entry: WeatherCachePayload) -> PassengerWeatherCardModel {
        let timing = timingFromStorage(key: entry.timing, weekdayName: entry.weekdayName)
        let (advice, emoji) = clothingAdvice(
            tempC: entry.tempC,
            precipitation: entry.precipitation,
            rain: entry.rain
        )
        return PassengerWeatherCardModel(
            placeName: entry.placeName,
            temperatureC: Int(entry.tempC.rounded()),
            advice: advice,
            emoji: emoji,
            timing: timing
        )
    }

    private static func timingLabel(for targetMorning: Date, reference: Date) -> PassengerWeatherTiming {
        let cal = HolidayMode.calendar
        let refDay = cal.startOfDay(for: reference)
        let targetDay = cal.startOfDay(for: targetMorning)
        let dayDiff = cal.dateComponents([.day], from: refDay, to: targetDay).day ?? 0

        switch dayDiff {
        case 0:
            return .todayMorning
        case 1:
            return .tomorrowMorning
        default:
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: LanguageManager.shared.language.rawValue)
            formatter.dateFormat = "EEEE"
            return .weekdayMorning(formatter.string(from: targetMorning).capitalized)
        }
    }

    private static func timingStorageKey(_ timing: PassengerWeatherTiming) -> String {
        switch timing {
        case .todayMorning: return "today"
        case .tomorrowMorning: return "tomorrow"
        case .weekdayMorning: return "weekday"
        }
    }

    private static func weekdayStorageName(_ timing: PassengerWeatherTiming) -> String? {
        if case .weekdayMorning(let name) = timing { return name }
        return nil
    }

    private static func timingFromStorage(key: String, weekdayName: String?) -> PassengerWeatherTiming {
        switch key {
        case "today": return .todayMorning
        case "tomorrow": return .tomorrowMorning
        default: return .weekdayMorning(weekdayName ?? "")
        }
    }

    private static func nextWorkdayStart(from reference: Date, afterToday: Bool = false) -> Date {
        let cal = HolidayMode.calendar
        var date = cal.startOfDay(for: reference)

        if afterToday {
            date = cal.date(byAdding: .day, value: 1, to: date) ?? date
        }

        var weekday = cal.component(.weekday, from: date)
        while weekday == 1 || weekday == 7 {
            date = cal.date(byAdding: .day, value: 1, to: date) ?? date
            weekday = cal.component(.weekday, from: date)
        }

        return date
    }

    private static func isValidCoordinate(_ coordinate: CLLocationCoordinate2D) -> Bool {
        let lat = coordinate.latitude
        let lng = coordinate.longitude
        guard lat.isFinite, lng.isFinite else { return false }
        guard abs(lat) <= 90, abs(lng) <= 180 else { return false }
        guard abs(lat) > 0.01 || abs(lng) > 0.01 else { return false }
        return true
    }

    private struct WeatherReading {
        let tempC: Double
        let precipitation: Double
        let rain: Double
    }

    private static func fetchMorningForecast(
        latitude: Double,
        longitude: Double,
        targetMorning: Date,
        forecastHour: Int
    ) async -> WeatherReading? {
        var components = URLComponents(url: openMeteoURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "hourly", value: "temperature_2m,precipitation,rain"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "7"),
        ]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8

        let cal = HolidayMode.calendar
        var targetComponents = cal.dateComponents([.year, .month, .day], from: targetMorning)
        targetComponents.hour = forecastHour
        targetComponents.minute = 0
        guard let targetDate = cal.date(from: targetComponents) else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = cal.timeZone
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
                return nil
            }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let hourly = json?["hourly"] as? [String: Any]
            let times = hourly?["time"] as? [String] ?? []
            let temperatures = hourly?["temperature_2m"] as? [Double] ?? []
            let precipitations = hourly?["precipitation"] as? [Double] ?? []
            let rains = hourly?["rain"] as? [Double] ?? []

            let targetToken = formatter.string(from: targetDate)
            guard let index = times.firstIndex(of: targetToken),
                  index < temperatures.count
            else {
                return nil
            }

            let temp = temperatures[index]
            let precipitation = index < precipitations.count ? precipitations[index] : 0
            let rain = index < rains.count ? rains[index] : 0
            return WeatherReading(tempC: temp, precipitation: precipitation, rain: rain)
        } catch {
            return nil
        }
    }

    /// Mahalle adı — iOS/Android aynı kaynak (OSM); şehir/ilçe gösterilmez.
    private static func resolvePlaceName(for coordinate: CLLocationCoordinate2D) async -> String {
        if let neighborhood = await fetchNeighborhoodFromNominatim(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        ) {
            return neighborhood
        }

        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let suburb = placemarks.first?.subLocality, !suburb.isEmpty {
                return suburb
            }
        } catch {
            // Fallback below
        }
        return L10n.pickupPlaceFallback
    }

    private static func fetchNeighborhoodFromNominatim(latitude: Double, longitude: Double) async -> String? {
        var components = URLComponents(url: nominatimURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(latitude)),
            URLQueryItem(name: "lon", value: String(longitude)),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "accept-language", value: LanguageManager.shared.language.rawValue),
            URLQueryItem(name: "zoom", value: "17"),
        ]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("BusTracker/1.3 (passenger-clothing-advice)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
                return nil
            }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let address = json?["address"] as? [String: Any]
            for key in neighborhoodAddressKeys {
                if let value = address?[key] as? String {
                    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { return trimmed }
                }
            }
            return nil
        } catch {
            return nil
        }
    }

    private static func clothingAdvice(
        tempC: Double,
        precipitation: Double,
        rain: Double
    ) -> (String, String) {
        let wet = precipitation >= wetMm || rain >= wetMm
        if wet {
            return (L10n.adviceRain, "🌧️")
        }
        if tempC <= coldTempC {
            return (L10n.adviceColdHat, "🧣")
        }
        if tempC >= hotTempC {
            return (L10n.adviceVeryHot, "☀️")
        }
        if tempC >= 22 {
            return (L10n.adviceHot, "☀️")
        }
        if tempC >= 12 {
            return (L10n.adviceCool, "🧥")
        }
        return (L10n.adviceCold, "🧣")
    }
}
