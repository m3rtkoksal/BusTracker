import Foundation
import FirebaseFirestore

enum DriverSubscriptionService {
    private static var db: Firestore { Firestore.firestore() }

    static func fetchPoolState(
        groupID: String,
        source: FirestoreSource = .default
    ) async -> ShuttlePoolState {
        guard !groupID.isEmpty else { return .empty }

        do {
            let snapshot = try await db.collection("groups").document(groupID).getDocument(source: source)
            guard snapshot.exists, let data = snapshot.data() else { return .empty }

            let startDate = (data["subscriptionStartDate"] as? Timestamp)?.dateValue()
            let endDate = (data["subscriptionEndDate"] as? Timestamp)?.dateValue()
            let poolMode = ShuttlePoolMode(rawValue: data["poolMode"] as? String ?? "") ?? .monthly
            let poolTarget = data["poolTarget"] as? Int ?? poolMode.targetAmount
            let poolCollected = data["poolCollected"] as? Int ?? 0

            return ShuttlePoolState(
                subscription: DriverSubscriptionInfo(startDate: startDate, endDate: endDate),
                poolMode: poolMode,
                poolTarget: poolTarget,
                poolCollected: poolCollected
            )
        } catch {
            return .empty
        }
    }

    static func fetchSubscription(groupID: String) async -> DriverSubscriptionInfo {
        await fetchPoolState(groupID: groupID).subscription
    }

    static func updatePoolMode(groupID: String, mode: ShuttlePoolMode) async throws {
        guard !groupID.isEmpty else { return }
        try await db.collection("groups").document(groupID).setData(
            [
                "poolMode": mode.rawValue,
                "poolTarget": mode.targetAmount,
            ],
            merge: true
        )
    }
}
