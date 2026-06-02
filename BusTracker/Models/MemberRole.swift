import Foundation

enum MemberRole: String, Codable, CaseIterable, Hashable {
    case driver
    case passenger

    var title: String {
        switch self {
        case .driver: L10n.roleDriver
        case .passenger: L10n.rolePassenger
        }
    }
}
