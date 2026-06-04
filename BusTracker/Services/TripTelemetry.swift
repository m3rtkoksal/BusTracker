import CoreLocation
import FirebaseFirestore
import Foundation

enum TripTelemetry {
    /// Sürücü telemetrisi — bindi analizi (~3 dk hareket + durak geçmişi).
    static let sampleWindowSeconds: TimeInterval = 900
    static let maxStoredSamples = 48

    struct Sample: Codable, Equatable {
        let speedMps: Double
        let latitude: Double
        let longitude: Double
        let sampledAt: Date
    }

    static func speedMps(from location: CLLocation, previous: CLLocation?) -> Double {
        if location.speed >= 0 {
            return location.speed
        }
        guard let previous else { return 0 }
        let dt = location.timestamp.timeIntervalSince(previous.timestamp)
        guard dt > 0 else { return 0 }
        return location.distance(from: previous) / dt
    }

    static func firestorePayload(for sample: Sample) -> [String: Any] {
        [
            "speedMps": sample.speedMps,
            "latitude": sample.latitude,
            "longitude": sample.longitude,
            "sampledAt": sample.sampledAt
        ]
    }

    static func samples(from data: [String: Any]?) -> [Sample] {
        guard let raw = data?["samples"] as? [[String: Any]] else { return [] }
        let cutoff = Date().addingTimeInterval(-sampleWindowSeconds)
        return raw.compactMap { entry -> Sample? in
            guard
                let speed = numeric(entry["speedMps"]),
                let lat = numeric(entry["latitude"]),
                let lng = numeric(entry["longitude"])
            else { return nil }
            let at: Date
            if let timestamp = entry["sampledAt"] as? Timestamp {
                at = timestamp.dateValue()
            } else if let timestamp = entry["sampledAt"] as? Date {
                at = timestamp
            } else if let seconds = entry["sampledAt"] as? TimeInterval {
                at = Date(timeIntervalSince1970: seconds)
            } else {
                return nil
            }
            guard at >= cutoff else { return nil }
            return Sample(speedMps: speed, latitude: lat, longitude: lng, sampledAt: at)
        }
        .sorted { $0.sampledAt < $1.sampledAt }
    }

    private static func numeric(_ value: Any?) -> Double? {
        switch value {
        case let double as Double: double
        case let number as NSNumber: number.doubleValue
        case let int as Int: Double(int)
        default: nil
        }
    }
}
