import Foundation

enum MemberRole: String, Codable, CaseIterable, Hashable {
    case driver
    case passenger

    var title: String {
        switch self {
        case .driver: "Sürücü"
        case .passenger: "Yolcu"
        }
    }
}
