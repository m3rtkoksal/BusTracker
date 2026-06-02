import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct RegistrationFlowView: View {
    let onLoginTapped: () -> Void

    @Environment(SmlerInviteCoordinator.self) private var smlerInviteCoordinator
    @State private var path = NavigationPath()
    @State private var showNotificationSettingsAlert = false

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
        .task { await refreshNotificationAccess() }
#if canImport(UIKit)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await refreshNotificationAccess() }
        }
#endif
        .alert(L10n.notificationsDisabledTitle, isPresented: $showNotificationSettingsAlert) {
            Button(L10n.openSettings) {
                NotificationService.shared.openSystemSettings()
            }
            Button(L10n.later, role: .cancel) {}
        } message: {
            Text(L10n.notificationsDisabledMessage)
        }
    }

    /// Deeplink / deferred davet: rol seçimi yerine doğrudan yolcu kayıt formu.
    private func openPassengerRegistrationIfInvited() {
        guard smlerInviteCoordinator.hasPassengerRegistrationInvite else { return }
        smlerInviteCoordinator.preparePassengerRegistrationFromDeferred()
        guard path.isEmpty else { return }
        path.append(MemberRole.passenger)
    }

    private func refreshNotificationAccess() async {
        let result = await NotificationService.shared.ensureNotificationsEnabled(
            groupID: nil,
            memberID: nil
        )
        if result == .needsSettings {
            showNotificationSettingsAlert = true
        }
    }
}

#Preview {
    RegistrationFlowView(onLoginTapped: {})
        .environment(ShuttleStore())
        .environment(UserSession.shared)
        .environment(AuthService.shared)
        .environment(SmlerInviteCoordinator())
}
