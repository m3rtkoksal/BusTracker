import Foundation
import FirebaseFirestore
import SwiftUI

@MainActor
@Observable
final class DriverSubscriptionViewModel {
    private(set) var poolState = ShuttlePoolState.empty
    private(set) var isLoading = false
    private(set) var toast: PopupPresentation?

    var subscription: DriverSubscriptionInfo { poolState.subscription }

    var startDateText: String {
        DriverSubscriptionDisplay.formatDate(poolState.subscription.startDate)
    }

    var endDateText: String {
        DriverSubscriptionDisplay.formatDate(poolState.subscription.endDate)
    }

    var statusSubtitle: String {
        if poolState.subscription.isExpiringSoon, let days = poolState.subscription.daysRemaining {
            return L10n.subscriptionExpiringSoonSubtitle(daysRemaining: days)
        }
        if poolState.isServiceOperational {
            return endDateText
        }
        if poolState.remainingBalance > 0 {
            return ShuttlePoolDisplay.formatCurrency(poolState.remainingBalance)
        }
        return L10n.subscriptionInactive
    }

    var expiringSoonMessage: String? {
        guard poolState.subscription.isExpiringSoon,
              let days = poolState.subscription.daysRemaining else { return nil }
        return L10n.subscriptionExpiringSoonMessage(endDate: endDateText, daysRemaining: days)
    }

    var isExpiringSoon: Bool {
        poolState.subscription.isExpiringSoon
    }

    func load(groupID: String, preferServer: Bool = false) async {
        guard !groupID.isEmpty else {
            poolState = .empty
            return
        }
        isLoading = true
        defer { isLoading = false }
        let source: FirestoreSource = preferServer ? .server : .default
        poolState = await DriverSubscriptionService.fetchPoolState(groupID: groupID, source: source)
    }

    func applyContributionResult(_ result: PoolContributionResult) {
        poolState.poolCollected = result.poolCollected
        poolState.poolTarget = result.poolTarget
    }

    func showSuccess(_ message: String) {
        toast = PopupPresentation(style: .success, title: L10n.success, message: message)
    }

    func clearToast() {
        toast = nil
    }

    func setPoolMode(_ mode: ShuttlePoolMode, groupID: String) async {
        guard poolState.poolMode != mode else { return }
        poolState.poolMode = mode
        poolState.poolTarget = mode.targetAmount
        do {
            try await DriverSubscriptionService.updatePoolMode(groupID: groupID, mode: mode)
        } catch {
            await load(groupID: groupID)
        }
    }
}
