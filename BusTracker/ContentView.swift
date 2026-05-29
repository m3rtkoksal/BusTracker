import SwiftUI

struct ContentView: View {
    @Environment(UserSession.self) private var session
    @Environment(AuthService.self) private var authService
    @Environment(LocationTracker.self) private var locationTracker

    @State private var authMode: AuthMode = .register

    enum AuthMode {
        case register, login
    }

    private var isAuthenticatedWithProfile: Bool {
        session.profile != nil && authService.isSignedIn
    }

    var body: some View {
        Group {
            if isAuthenticatedWithProfile, let profile = session.profile {
                homeView(for: profile)
                    .task {
                        await NotificationService.shared.requestPermissionIfNeeded()
                    }
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
        .task(id: locationPermissionTaskID) {
            locationTracker.requestWhenInUsePermissionIfNeeded()
        }
    }

    /// Giriş, kayıt veya ana ekran: Android ile aynı — when-in-use isteği.
    private var locationPermissionTaskID: String {
        if isAuthenticatedWithProfile, let memberID = session.profile?.memberID {
            return "signed-\(memberID)"
        }
        return "auth-\(authMode)"
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
