import Foundation

struct ShuttleMember: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let role: MemberRole
    var attendance: AttendanceStatus

    init(id: String, name: String, role: MemberRole, attendance: AttendanceStatus = .unknown) {
        self.id = id
        self.name = name
        self.role = role
        self.attendance = attendance
    }
}
