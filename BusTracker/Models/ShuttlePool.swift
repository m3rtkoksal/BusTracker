import Foundation

enum ShuttlePoolMode: String, Equatable, CaseIterable {
    case monthly
    case annual

    var targetAmount: Int {
        switch self {
        case .monthly: ShuttlePoolConfig.monthlyTarget
        case .annual: ShuttlePoolConfig.annualTarget
        }
    }

    var extensionDays: Int {
        switch self {
        case .monthly: 30
        case .annual: 365
        }
    }
}

enum ShuttlePoolConfig {
    static let monthlyTarget = 99
    static let annualTarget = 1000
    static let gracePeriodDays = 7
    static let expiringSoonDays = 7
    static let contributionTiers = [50, 100, 250, 500, 1000]

    /// Pilot süresince süre bitişi / grace sonrası servis kapatma ve uyarı banner'ları kapalı.
    /// Pilot bitince `false` yap.
    static let pilotModeEnforcementDisabled = true
}

enum ShuttlePoolProduct: Int, CaseIterable, Identifiable {
    case tier50 = 50
    case tier100 = 100
    case tier250 = 250
    case tier500 = 500
    case tier1000 = 1000

    var id: Int { rawValue }

    var amount: Int { rawValue }

    var productID: String {
        "com.mikatechnology.BusTracker.pool.\(rawValue)"
    }

    static var allProductIDs: [String] {
        allCases.map(\.productID)
    }

    static func matching(amount: Int) -> ShuttlePoolProduct? {
        allCases.first { $0.rawValue == amount }
    }
}

struct PoolContributionResult: Equatable {
    let poolCollected: Int
    let poolTarget: Int
    let activated: Bool
}

struct ShuttlePoolState: Equatable {
    var subscription: DriverSubscriptionInfo
    var poolMode: ShuttlePoolMode
    var poolTarget: Int
    var poolCollected: Int

    static let empty = ShuttlePoolState(
        subscription: .empty,
        poolMode: .monthly,
        poolTarget: ShuttlePoolConfig.monthlyTarget,
        poolCollected: 0
    )

    var remainingBalance: Int {
        max(0, poolTarget - poolCollected)
    }

    var isPoolComplete: Bool {
        poolCollected >= poolTarget
    }

    var isServiceOperational: Bool {
        subscription.isServiceOperational
    }
}

enum ShuttlePoolDisplay {
    @MainActor
    static func formatCurrency(_ amount: Int) -> String {
        L10n.poolCurrency(amount)
    }
}
