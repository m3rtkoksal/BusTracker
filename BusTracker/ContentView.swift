import SwiftUI

struct ContentView: View {
    @Environment(UserSession.self) private var session
    @Environment(AuthService.self) private var authService
    @Environment(ShuttleStore.self) private var store

    @State private var authMode: AuthMode = .register
    @State private var isLoadingProfile = false

    enum AuthMode {
        case register, login
    }

    var body: some View {
        Group {
            if let profile = session.profile {
                homeView(for: profile)
            } else if isLoadingProfile {
                ProgressView("Giriş yapılıyor...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            await loadExistingSessionIfNeeded()
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

    private func loadExistingSessionIfNeeded() async {
        guard authService.isSignedIn,
              !authService.isCompletingRegistration,
              session.profile == nil,
              let userID = authService.currentUserID else { return }

        isLoadingProfile = true
        defer { isLoadingProfile = false }

        do {
            if let profile = try await store.fetchUserProfile(userID: userID) {
                session.save(profile)
                await NotificationService.shared.requestPermissionAndRegister()
                // Only attempt to save the token if we have a valid group and member ID
                let effectiveGroupID = profile.groupID ?? profile.primaryGroupID
                let memberID = profile.memberID

                if !effectiveGroupID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    await NotificationService.shared.saveTokenToProfile(
                        groupID: effectiveGroupID,
                        memberID: memberID
                    )
                }
            }
        } catch {
            // Kayıt veya geçici ağ hatasında oturumu kapatma; LoginView kendi hata akışını yönetir.
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
