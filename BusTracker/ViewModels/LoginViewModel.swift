import SwiftUI

@MainActor
@Observable
final class LoginViewModel: BaseViewModel {
    let onRegisterTapped: () -> Void

    init(onRegisterTapped: @escaping () -> Void) {
        self.onRegisterTapped = onRegisterTapped
        super.init()
        title = L10n.loginTitle
        navigationBarStyle = .auth
    }

    func signInWithApple(authService: AuthService, store: ShuttleStore, session: UserSession) async {
        setLoading(true, message: L10n.signingIn)
        defer { setLoading(false) }

        do {
            _ = try await authService.signInWithApple()
            guard let userID = authService.currentUserID else { return }

            if let profile = try await store.fetchUserProfile(userID: userID) {
                session.save(profile)

                let groupID = profile.primaryGroupID.isEmpty
                    ? (profile.groupID ?? "")
                    : profile.primaryGroupID
                if !groupID.isEmpty {
                    await NotificationService.shared.syncTokenIfAuthorized(
                        groupID: groupID,
                        memberID: profile.memberID
                    )
                } else {
                    showError(L10n.profileIncomplete)
                    try? authService.signOut()
                }
            } else {
                showError(L10n.profileNotFound)
                try? authService.signOut()
            }
        } catch let error as AppleSignInError {
            if case .cancelled = error { return }
            showError(authMessage(for: error))
        } catch {
            showError(authMessage(for: error))
        }
    }

    private func authMessage(for error: Error) -> String {
        if let authError = error as? AuthServiceError {
            return authError.localizedDescription
        }
        return AuthErrorMessage.message(for: error)
    }
}

struct LoginView: BaseView {
    @Environment(AuthService.self) private var authService
    @Environment(UserSession.self) private var session
    @Environment(ShuttleStore.self) private var store
    @State var viewModel: LoginViewModel

    init(onRegisterTapped: @escaping () -> Void) {
        _viewModel = State(initialValue: LoginViewModel(onRegisterTapped: onRegisterTapped))
    }

    func content() -> some View {
        ZStack {
            NeonBackgroundView()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(NeonTheme.secondary.opacity(0.12))
                                .frame(width: 96, height: 96)
                                .blur(radius: 24)

                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(NeonTheme.secondary.opacity(0.08))
                                .frame(width: 80, height: 80)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .strokeBorder(NeonTheme.secondary.opacity(0.35), lineWidth: 1)
                                }

                            Image(systemName: "person.crop.circle.badge.checkmark")
                                .font(.system(size: 34, weight: .medium))
                                .foregroundStyle(NeonTheme.secondary)
                                .shadow(color: NeonTheme.secondary.opacity(0.6), radius: 8)
                        }

                        Text(L10n.signInAction)
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundStyle(NeonTheme.onSurface)

                        Text(L10n.signInWithAppleHint)
                            .font(.subheadline)
                            .foregroundStyle(NeonTheme.onSurfaceVariant)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 12)

                    NeonGlassCard(accent: NeonTheme.secondary) {
                        VStack(spacing: 20) {
                            SignInWithAppleButton(
                                title: L10n.signInWithApple,
                                isLoading: authService.isLoading || viewModel.isLoading
                            ) {
                                Task {
                                    await viewModel.signInWithApple(
                                        authService: authService,
                                        store: store,
                                        session: session
                                    )
                                }
                            }
                        }
                        .padding(24)
                    }

                    Button(action: viewModel.onRegisterTapped) {
                        HStack(spacing: 4) {
                            Text(L10n.noAccount)
                                .foregroundStyle(NeonTheme.onSurfaceVariant)
                            Text(L10n.createAccount)
                                .fontWeight(.semibold)
                                .foregroundStyle(NeonTheme.secondary)
                        }
                        .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}
