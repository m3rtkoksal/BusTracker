import SwiftUI

enum PassengerHomeTab: String, CaseIterable {
    case service
    case map
    case settings

    var title: String {
        switch self {
        case .service: L10n.tabService
        case .map: L10n.tabMap
        case .settings: L10n.tabSettings
        }
    }

    var icon: String {
        switch self {
        case .service: "bus.fill"
        case .map: "map"
        case .settings: "slider.horizontal.3"
        }
    }
}

@MainActor
@Observable
final class PassengerTabBarController {
    var selectedTab: PassengerHomeTab = .map

    func select(_ tab: PassengerHomeTab) {
        selectedTab = tab
    }
}
