import Foundation

@MainActor
@Observable
final class DriverSubscriptionViewModel {
    private(set) var subscription = DriverSubscriptionInfo.empty
    private(set) var isLoading = false

    var startDateText: String {
        DriverSubscriptionDisplay.formatDate(subscription.startDate)
    }

    var endDateText: String {
        DriverSubscriptionDisplay.formatDate(subscription.endDate)
    }

    var statusSubtitle: String {
        if subscription.isExpiringSoon, let days = subscription.daysRemaining {
            return L10n.subscriptionExpiringSoonSubtitle(daysRemaining: days)
        }
        return subscription.isActive ? endDateText : L10n.subscriptionInactive
    }

    var expiringSoonMessage: String? {
        guard subscription.isExpiringSoon, let days = subscription.daysRemaining else { return nil }
        return L10n.subscriptionExpiringSoonMessage(endDate: endDateText, daysRemaining: days)
    }

    var isExpiringSoon: Bool {
        subscription.isExpiringSoon
    }

    func load(groupID: String) async {
        guard !groupID.isEmpty else {
            subscription = .empty
            return
        }
        isLoading = true
        defer { isLoading = false }
        subscription = await DriverSubscriptionService.fetchSubscription(groupID: groupID)
    }
}
