import Foundation

enum AttendanceStatus: String, Codable, CaseIterable {
    case coming
    case notComing
    case unknown

    var title: String {
        switch self {
        case .coming: "Gelecek"
        case .notComing: "Gelmeyecek"
        case .unknown: "Belirtmedi"
        }
    }

    var iconName: String {
        switch self {
        case .coming: "checkmark.circle.fill"
        case .notComing: "xmark.circle.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }

    /// Harita sekmesi sol üst katılım kutusu.
    var mapTabLabel: String {
        switch self {
        case .coming: "Geliyorum"
        case .notComing: "Gelmiyorum"
        case .unknown: "Belirsiz"
        }
    }
}
