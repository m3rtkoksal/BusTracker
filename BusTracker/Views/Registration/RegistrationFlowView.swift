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
        .task { await refreshNotificationAccess() }
#if canImport(UIKit)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await refreshNotificationAccess() }
        }
#endif
        .alert("Bildirimler kapalı", isPresented: $showNotificationSettingsAlert) {
            Button("Ayarları Aç") {
                NotificationService.shared.openSystemSettings()
            }
            Button("Sonra", role: .cancel) {}
        } message: {
            Text("Servis başladığında haberdar olmak için bildirimleri açın.")
        }
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
