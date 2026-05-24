import SwiftUI

struct PassengerListView: View {
    let members: [ShuttleMember]
    var showDriver: Bool = true

    private var passengers: [ShuttleMember] {
        members.filter { showDriver || $0.role == .passenger }
    }

    var body: some View {
        if passengers.isEmpty {
            ContentUnavailableView(
                "Henüz yolcu yok",
                systemImage: "person.3",
                description: Text("Yolcular servis kodunu girerek katılabilir.")
            )
        } else {
            List(passengers) { member in
                HStack(spacing: 12) {
                    Image(systemName: member.attendance.iconName)
                        .foregroundStyle(color(for: member.attendance))
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
                        Text(member.attendance.title)
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
}
