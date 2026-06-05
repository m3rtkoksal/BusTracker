import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ContentView: View {
    @Environment(UserSession.self) private var session
    @Environment(AuthService.self) private var authService
    @Environment(LocationTracker.self) private var locationTracker
    @Environment(ShuttleStore.self) private var store
    @Environment(SmlerInviteCoordinator.self) private var smlerInviteCoordinator
    @State private var authMode: AuthMode = .register
    enum AuthMode {
        case register, login
    }

    private var isAuthenticatedWithProfile: Bool {
        session.profile != nil && authService.isSignedIn
    }

    /// Sürücü: yalnızca bildirim (açılışta). Konum/hareket → Servisi başlat akışı.
    private var appPermissionsNotificationsOnly: Bool {
        guard isAuthenticatedWithProfile, let profile = session.profile else {
            return true
        }
        return profile.role == .driver
    }

    var body: some View {
        Group {
            if isAuthenticatedWithProfile, let profile = session.profile {
                homeView(for: profile)
            } else {
                switch authMode {
                case .register:
                    RegistrationFlowView { authMode = .login }
                case .login:
                    LoginView { authMode = .register }
                }
            }
        }
        .task(id: authService.isSignedIn) {
            if !authService.isSignedIn, session.profile != nil {
                session.clearLocalProfile()
            }
        }
        .appPermissionsHandler(
            profile: isAuthenticatedWithProfile ? session.profile : nil,
            notificationsOnly: appPermissionsNotificationsOnly,
            enabled: isAuthenticatedWithProfile
        )
        .task(id: smlerInviteRoutingTaskID) {
            await smlerInviteCoordinator.handleIfReady(
                profile: session.profile,
                isSignedIn: authService.isSignedIn,
                store: store
            )
        }
        .alert(L10n.shuttleInvite, isPresented: smlerInviteAlertBinding) {
            Button(L10n.ok, role: .cancel) {
                smlerInviteCoordinator.dismissAlreadyMemberMessage()
            }
        } message: {
            Text(smlerInviteCoordinator.alreadyMemberMessage ?? "")
        }
    }

    private var smlerInviteRoutingTaskID: String {
        let profileID = session.profile?.memberID ?? "none"
        return "\(smlerInviteCoordinator.inviteRevision)-\(authService.isSignedIn)-\(profileID)"
    }

    private var smlerInviteAlertBinding: Binding<Bool> {
        Binding(
            get: { smlerInviteCoordinator.alreadyMemberMessage != nil },
            set: { if !$0 { smlerInviteCoordinator.dismissAlreadyMemberMessage() } }
        )
    }

    @ViewBuilder
    private func homeView(for profile: UserProfile) -> some View {
        switch profile.role {
        case .driver:
            DriverHomeView()
        case .passenger:
            PassengerHomeView()
        }
    }
}

#Preview {
    ContentView()
        .environment(UserSession.shared)
        .environment(AuthService.shared)
        .environment(ShuttleStore())
        .environment(LocationTracker())
}
