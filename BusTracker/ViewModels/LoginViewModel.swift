import SwiftUI

@MainActor
@Observable
final class LoginViewModel: BaseViewModel {
    let onRegisterTapped: () -> Void

    init(onRegisterTapped: @escaping () -> Void) {
        self.onRegisterTapped = onRegisterTapped
        super.init()
        title = "Giriş"
        navigationBarStyle = .auth
    }

    func signInWithApple(authService: AuthService, store: ShuttleStore, session: UserSession) async {
        setLoading(true, message: "Giriş yapılıyor...")
        defer { setLoading(false) }

        do {
            await NotificationService.shared.requestPermissionIfNeeded()
            _ = try await authService.signInWithApple()
            guard let userID = authService.currentUserID else { return }

            if let profile = try await store.fetchUserProfile(userID: userID) {
                session.save(profile)
                await NotificationService.shared.requestPermissionIfNeeded()

                let groupID = profile.groupID ?? profile.primaryGroupID
                if !groupID.isEmpty {
                    await NotificationService.shared.saveTokenToProfile(
                        groupID: groupID,
                        memberID: profile.memberID
                    )
                } else {
                    showError("Profil bilgileri eksik. Lütfen tekrar deneyin.")
                    try? authService.signOut()
                }
            } else {
                showError("Bu Apple hesabıyla kayıtlı profil bulunamadı. Hesabınız silinmiş olabilir; yeni hesap oluşturabilirsiniz.")
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

                        Text("Giriş Yap")
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundStyle(NeonTheme.onSurface)

                        Text("Apple hesabınızla giriş yapın.")
                            .font(.subheadline)
                            .foregroundStyle(NeonTheme.onSurfaceVariant)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 12)

                    NeonGlassCard(accent: NeonTheme.secondary) {
                        VStack(spacing: 20) {
                            SignInWithAppleButton(
                                title: "Apple ile Giriş Yap",
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
                            Text("Hesabın yok mu?")
                                .foregroundStyle(NeonTheme.onSurfaceVariant)
                            Text("Hesap oluştur")
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
