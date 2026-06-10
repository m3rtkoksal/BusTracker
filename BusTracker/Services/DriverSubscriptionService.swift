import Foundation
import FirebaseFirestore

enum DriverSubscriptionConfig {
    static let renewalPageBaseURL = "https://mika.technology/subscribe"

    static func renewalPageURL(serviceCode: String) -> URL {
        let code = serviceCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty,
              var components = URLComponents(string: renewalPageBaseURL) else {
            return URL(string: renewalPageBaseURL)!
        }
        components.queryItems = [URLQueryItem(name: "code", value: code)]
        return components.url ?? URL(string: renewalPageBaseURL)!
    }
}

enum DriverSubscriptionService {
    private static var db: Firestore { Firestore.firestore() }

    static func fetchSubscription(groupID: String) async -> DriverSubscriptionInfo {
        guard !groupID.isEmpty else { return .empty }

        do {
            let snapshot = try await db.collection("groups").document(groupID).getDocument()
            guard snapshot.exists, let data = snapshot.data() else { return .empty }

            let startDate = (data["subscriptionStartDate"] as? Timestamp)?.dateValue()
            let endDate = (data["subscriptionEndDate"] as? Timestamp)?.dateValue()
            return DriverSubscriptionInfo(startDate: startDate, endDate: endDate)
        } catch {
            return .empty
        }
    }
}
