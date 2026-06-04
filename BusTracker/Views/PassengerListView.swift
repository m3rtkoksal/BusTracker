import SwiftUI

struct PassengerListView: View {
    @Environment(ShuttleStore.self) private var store
    let members: [ShuttleMember]
    var showDriver: Bool = true

    private var passengers: [ShuttleMember] {
        members.filter { showDriver || $0.role == .passenger }
    }

    var body: some View {
        if passengers.isEmpty {
            ContentUnavailableView(
                L10n.noPassengersYet,
                systemImage: "person.3",
                description: Text(L10n.passengersJoinWithCode)
            )
        } else {
            List(passengers) { member in
                HStack(spacing: 12) {
                    let attendance = store.serviceDayAttendance(for: member)
                    Image(systemName: member.isBoardedToday ? "bus.fill" : attendance.iconName)
                        .foregroundStyle(
                            member.isBoardedToday ? .green : color(for: attendance)
                        )
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(member.name)
                                .font(.body.weight(.medium))
                            if member.role == .driver {
                                Text(member.role.title)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(.blue.opacity(0.15)))
                            }
                        }
                        Text(member.isBoardedToday ? L10n.attendanceBoarded : attendance.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
            .listStyle(.plain)
        }
    }

    private func color(for status: AttendanceStatus) -> Color {
        switch status {
        case .coming: .green
        case .notComing: .red
        case .unknown: .orange
        }
    }
}

#Preview {
    PassengerListView(members: [
        ShuttleMember(id: "1", name: "Ayşe", role: .passenger, attendance: .coming),
        ShuttleMember(id: "2", name: "Mehmet", role: .passenger, attendance: .notComing),
        ShuttleMember(id: "3", name: "Ali", role: .driver, attendance: .unknown)
    ])
    .environment(ShuttleStore())
}
