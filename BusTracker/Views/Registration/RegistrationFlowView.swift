import SwiftUI

struct RegistrationFlowView: View {
    let onLoginTapped: () -> Void

    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            RoleSelectionView(
                onLoginTapped: onLoginTapped,
                onSelectDriver: { path.append(MemberRole.driver) },
                onSelectPassenger: { path.append(MemberRole.passenger) }
            )
            .navigationDestination(for: MemberRole.self) { role in
                RegistrationFormView(role: role, onBack: { path.removeLast() })
            }
        }
        .task {
            await NotificationService.shared.requestPermissionIfNeeded()
        }
    }
}

#Preview {
    RegistrationFlowView(onLoginTapped: {})
        .environment(ShuttleStore())
        .environment(UserSession.shared)
        .environment(AuthService.shared)
}
