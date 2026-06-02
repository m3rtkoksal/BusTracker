import CoreLocation
import Foundation

struct PassengerWeatherCardModel: Equatable {
    let placeName: String
    let temperatureC: Int
    /// Push bildirimiyle aynı tarz giyim önerisi.
    let advice: String
    let emoji: String

    var contextLine: String {
        L10n.weatherContext(placeName, temperatureC)
    }
}

enum PassengerWeatherService {
    private static let openMeteoURL = URL(string: "https://api.open-meteo.com/v1/forecast")!
    private static let nominatimURL = URL(string: "https://nominatim.openstreetmap.org/reverse")!
    private static let cacheTTL: TimeInterval = 3600
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

    private struct WeatherCachePayload: Codable {
        let latitude: Double
        let longitude: Double
        let placeName: String
        let tempC: Double
        let precipitation: Double
        let rain: Double
        let fetchedAt: Date
    }

    @MainActor
    static func cachedModel(for coordinate: CLLocationCoordinate2D) -> PassengerWeatherCardModel? {
        guard isValidCoordinate(coordinate),
              let entry = cachedEntry(for: coordinate) else { return nil }
        return model(from: entry)
    }

    @MainActor
    static func load(for coordinate: CLLocationCoordinate2D) async -> PassengerWeatherCardModel? {
        guard isValidCoordinate(coordinate) else { return nil }

        if let entry = cachedEntry(for: coordinate) {
            return model(from: entry)
        }

        async let weatherTask = fetchWeather(latitude: coordinate.latitude, longitude: coordinate.longitude)
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
            fetchedAt: Date()
        )
        saveCache(entry, for: coordinate)
        return model(from: entry)
    }

    private static func cacheStorageKey(for coordinate: CLLocationCoordinate2D) -> String {
        cacheKeyPrefix + String(format: "%.4f,%.4f", coordinate.latitude, coordinate.longitude)
    }

    private static func cachedEntry(for coordinate: CLLocationCoordinate2D) -> WeatherCachePayload? {
        let key = cacheStorageKey(for: coordinate)
        guard let data = UserDefaults.standard.data(forKey: key),
              let entry = try? JSONDecoder().decode(WeatherCachePayload.self, from: data),
              Date().timeIntervalSince(entry.fetchedAt) < cacheTTL else {
            return nil
        }
        return entry
    }

    private static func saveCache(_ entry: WeatherCachePayload, for coordinate: CLLocationCoordinate2D) {
        guard let data = try? JSONEncoder().encode(entry) else { return }
        UserDefaults.standard.set(data, forKey: cacheStorageKey(for: coordinate))
    }

    private static func model(from entry: WeatherCachePayload) -> PassengerWeatherCardModel {
        let (advice, emoji) = clothingAdvice(
            tempC: entry.tempC,
            precipitation: entry.precipitation,
            rain: entry.rain
        )
        return PassengerWeatherCardModel(
            placeName: entry.placeName,
            temperatureC: Int(entry.tempC.rounded()),
            advice: advice,
            emoji: emoji
        )
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

    private static func fetchWeather(latitude: Double, longitude: Double) async -> WeatherReading? {
        var components = URLComponents(url: openMeteoURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,precipitation,rain"),
            URLQueryItem(name: "timezone", value: "auto"),
        ]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
                return nil
            }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let current = json?["current"] as? [String: Any]
            guard let temp = current?["temperature_2m"] as? Double else { return nil }
            let precipitation = (current?["precipitation"] as? Double) ?? 0
            let rain = (current?["rain"] as? Double) ?? 0
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
