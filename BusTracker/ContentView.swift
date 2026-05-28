import SwiftUI

struct ContentView: View {
    @Environment(UserSession.self) private var session
    @Environment(AuthService.self) private var authService

    @State private var authMode: AuthMode = .register

    enum AuthMode {
        case register, login
    }

    var body: some View {
        Group {
            if let profile = session.profile {
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
