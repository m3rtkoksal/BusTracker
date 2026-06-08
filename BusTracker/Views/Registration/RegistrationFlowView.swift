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
        .task {
            await processDeferredSmlerInviteIfNeeded()
        }
        .task(id: smlerInviteCoordinator.inviteRevision) {
            openPassengerRegistrationIfInvited()
        }
    }

    /// App Store sonrası ilk açılış: launch URL → pano → probabilistic (Smler deferred).
    private func processDeferredSmlerInviteIfNeeded() async {
        smlerInviteCoordinator.restorePersistedRegistrationInviteIfNeeded()

        if let launchURL = SmlerPendingInviteURL.consume() {
            await smlerInviteCoordinator.processIncomingURL(launchURL)
        }

        if smlerInviteCoordinator.hasPassengerRegistrationInvite {
            openPassengerRegistrationIfInvited()
            return
        }

        guard let code = await SmlerDeepLinkService.shared.serviceCodeFromDeferredInstall() else { return }
        smlerInviteCoordinator.ingest(serviceCode: code)
        openPassengerRegistrationIfInvited()
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
