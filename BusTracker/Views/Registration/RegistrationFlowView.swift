import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct RegistrationFlowView: View {
    let onLoginTapped: () -> Void

    @Environment(SmlerInviteCoordinator.self) private var smlerInviteCoordinator
    @State private var path = NavigationPath()
    var body: some View {
        NavigationStack(path: $path) {
            RoleSelectionView(
                onLoginTapped: onLoginTapped,
                onSelectDriver: { path.append(MemberRole.driver) },
                onSelectPassenger: {
                    smlerInviteCoordinator.preparePassengerRegistrationFromDeferred()
                    path.append(MemberRole.passenger)
                }
            )
            .navigationDestination(for: MemberRole.self) { role in
                RegistrationFormView(role: role, onBack: { path.removeLast() })
            }
        }
        .task(id: smlerInviteCoordinator.inviteRevision) {
            openPassengerRegistrationIfInvited()
        }
    }

    /// Deeplink / deferred davet: rol seçimi yerine doğrudan yolcu kayıt formu.
    private func openPassengerRegistrationIfInvited() {
        guard smlerInviteCoordinator.hasPassengerRegistrationInvite else { return }
        smlerInviteCoordinator.preparePassengerRegistrationFromDeferred()
        guard path.isEmpty else { return }
        path.append(MemberRole.passenger)
    }

}

#Preview {
    RegistrationFlowView(onLoginTapped: {})
        .environment(ShuttleStore())
        .environment(UserSession.shared)
        .environment(AuthService.shared)
        .environment(SmlerInviteCoordinator())
}
