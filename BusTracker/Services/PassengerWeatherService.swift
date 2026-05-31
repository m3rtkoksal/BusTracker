import CoreLocation
import Foundation

struct PassengerWeatherCardModel: Equatable {
    let placeName: String
    let temperatureC: Int
    /// Push bildirimiyle aynı tarz giyim önerisi.
    let advice: String
    let emoji: String

    var contextLine: String {
        "Bugün \(placeName) · \(temperatureC)°"
    }
}

enum PassengerWeatherService {
    private static let openMeteoURL = URL(string: "https://api.open-meteo.com/v1/forecast")!
    private static let nominatimURL = URL(string: "https://nominatim.openstreetmap.org/reverse")!
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

    static func load(for coordinate: CLLocationCoordinate2D) async -> PassengerWeatherCardModel? {
        guard isValidCoordinate(coordinate) else { return nil }

        async let weatherTask = fetchWeather(latitude: coordinate.latitude, longitude: coordinate.longitude)
        async let placeTask = resolvePlaceName(for: coordinate)
        guard let weather = await weatherTask else { return nil }

        let placeName = await placeTask
        let (advice, emoji) = clothingAdvice(
            tempC: weather.tempC,
            precipitation: weather.precipitation,
            rain: weather.rain
        )

        return PassengerWeatherCardModel(
            placeName: placeName,
            temperatureC: Int(weather.tempC.rounded()),
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
        return "Biniş noktan"
    }

    private static func fetchNeighborhoodFromNominatim(latitude: Double, longitude: Double) async -> String? {
        var components = URLComponents(url: nominatimURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(latitude)),
            URLQueryItem(name: "lon", value: String(longitude)),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "accept-language", value: "tr"),
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
            return ("Yağmur var — şemsiyeni kap.", "🌧️")
        }
        if tempC <= coldTempC {
            return ("Hava soğuk — bere takmadan çıkma.", "🧣")
        }
        if tempC >= hotTempC {
            return ("Hava cehennem gibi — şapka tak, su al.", "☀️")
        }
        if tempC >= 22 {
            return ("Hava sıcak — şapka tak, su al.", "☀️")
        }
        if tempC >= 12 {
            return ("Hava serin — ince mont veya hırka al.", "🧥")
        }
        return ("Hava soğuk — kalın giyin.", "🧣")
    }
}
