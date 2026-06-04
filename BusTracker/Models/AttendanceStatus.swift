import Foundation

enum AttendanceStatus: String, Codable, CaseIterable {
    case coming
    case notComing
    case unknown

    var title: String {
        switch self {
        case .coming: L10n.attendanceComing
        case .notComing: L10n.attendanceNotComing
        case .unknown: L10n.attendanceUnknown
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
        case .coming: L10n.attendanceComingSelf
        case .notComing: L10n.attendanceNotComingSelf
        case .unknown: L10n.attendanceUncertain
        }
    }

    func mapTabLabel(isBoarded: Bool) -> String {
        isBoarded ? L10n.attendanceBoardedSelf : mapTabLabel
    }
}
