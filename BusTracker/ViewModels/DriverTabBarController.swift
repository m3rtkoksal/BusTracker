import SwiftUI

enum DriverHomeTab: String, CaseIterable {
    case passengers
    case map
    case settings

    var title: String {
        switch self {
        case .passengers: L10n.tabPassengers
        case .map: L10n.tabMap
        case .settings: L10n.tabSettings
        }
    }

    var icon: String {
        switch self {
        case .passengers: "person.3"
        case .map: "map"
        case .settings: "slider.horizontal.3"
        }
    }
}

@MainActor
@Observable
final class DriverTabBarController {
    var selectedTab: DriverHomeTab = .passengers

    func select(_ tab: DriverHomeTab) {
        selectedTab = tab
    }
}
