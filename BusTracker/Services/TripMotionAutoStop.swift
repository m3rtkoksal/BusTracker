import Foundation

/// Yolcu motion verisiyle seferin bitip bitmediğini değerlendirir.
/// Motion %100 güvenilir değil; tek okumaya güvenmeyip süre + araçtan çıkış şartı kullanılır.
enum TripMotionAutoStop {
    /// Sefer başladıktan sonra en az bu kadar süre geçmeden otomatik bitirme yapılmaz.
    static let minTripDurationSeconds: TimeInterval = 15 * 60
    /// Araçtan çıktıktan sonra walking sayılmadan önce beklenecek süre.
    static let minSecondsAfterVehicleExit: TimeInterval = 45
    /// Kesintisiz walking için gereken süre (yanlış pozitifleri azaltır).
    static let minWalkingSeconds: TimeInterval = 90
    /// Walking algılanmazsa stationary ile kabul için ek süre.
    static let stationaryFallbackExtraSeconds: TimeInterval = 30

    struct PassengerMotionSnapshot {
        let memberID: String
        let inVehicle: Bool
        let currentActivity: String
        let hasBeenInVehicle: Bool
        let lastVehicleExitAt: Date?
        let walkingSince: Date?
        let hadPickupReach: Bool
    }

    static func shouldAutoStopTrip(
        tripStartedAt: Date,
        comingMemberIDs: Set<String>,
        passengers: [PassengerMotionSnapshot],
        now: Date = Date()
    ) -> Bool {
        guard now.timeIntervalSince(tripStartedAt) >= minTripDurationSeconds else { return false }
        guard !comingMemberIDs.isEmpty else { return false }

        let trackableIDs = comingMemberIDs.filter { memberID in
            let snapshot = passengers.first { $0.memberID == memberID }
            guard let snapshot else { return false }
            return snapshot.hadPickupReach || snapshot.hasBeenInVehicle
        }
        guard !trackableIDs.isEmpty else { return false }

        let alightedCount = trackableIDs.count { memberID in
            guard let snapshot = passengers.first(where: { $0.memberID == memberID }) else { return false }
            return isAlighted(snapshot, now: now)
        }
        return alightedCount == trackableIDs.count
    }

    static func isAlighted(_ snapshot: PassengerMotionSnapshot, now: Date) -> Bool {
        guard snapshot.hadPickupReach || snapshot.hasBeenInVehicle else { return false }
        guard !snapshot.inVehicle else { return false }
        guard let exitAt = snapshot.lastVehicleExitAt else { return false }
        guard now.timeIntervalSince(exitAt) >= minSecondsAfterVehicleExit else { return false }

        if snapshot.currentActivity == "walking",
           let walkingSince = snapshot.walkingSince {
            return now.timeIntervalSince(walkingSince) >= minWalkingSeconds
        }

        if snapshot.currentActivity == "stationary" {
            return now.timeIntervalSince(exitAt) >= minWalkingSeconds + stationaryFallbackExtraSeconds
        }

        return false
    }
}
