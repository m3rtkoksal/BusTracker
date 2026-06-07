import Foundation

struct ShuttleMember: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    let role: MemberRole
    var attendance: AttendanceStatus
    /// `yyyy-MM-dd` — bitiş günü dahil tatil.
    var holidayModeEndDate: String?
    /// Bugünkü seferde servise bindi (otomatik telemetri).
    var boardedAt: Date?

    init(
        id: String,
        name: String,
        role: MemberRole,
        attendance: AttendanceStatus = .unknown,
        holidayModeEndDate: String? = nil,
        boardedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.attendance = attendance
        self.holidayModeEndDate = holidayModeEndDate
        self.boardedAt = boardedAt
    }

    var isBoardedToday: Bool {
        boardedAt != nil
    }
}
