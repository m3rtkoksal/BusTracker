import SwiftUI

struct RegistrationFormView: BaseView {
    @Environment(ShuttleStore.self) private var store
    @Environment(UserSession.self) private var session
    @Environment(AuthService.self) private var authService
    @Environment(SmlerInviteCoordinator.self) private var smlerInviteCoordinator
    let role: MemberRole
    let onBack: () -> Void

    @State var viewModel: RegistrationFormViewModel

    init(role: MemberRole, onBack: @escaping () -> Void) {
        self.role = role
        self.onBack = onBack
        _viewModel = State(initialValue: RegistrationFormViewModel(role: role))
    }

    func content() -> some View {
        ScrollView {
            VStack(spacing: 24) {
                NeonRegistrationHero(
                    icon: viewModel.heroIcon,
                    title: viewModel.heroTitle,
                    subtitle: viewModel.heroSubtitle,
                    accent: viewModel.accent
                )

                NeonGlassCard(accent: viewModel.accent) {
                    VStack(spacing: 20) {
                        NeonFormField(title: L10n.yourNameField, text: $viewModel.name, prompt: viewModel.namePrompt)
                        NeonFormField(
                            title: viewModel.serviceFieldTitle,
                            text: serviceFieldBinding,
                            prompt: viewModel.serviceFieldPrompt,
                            keyboard: role == .passenger ? .asciiCapable : .default,
                            textInputAutocapitalization: role == .passenger ? .characters : .words,
                            errorText: viewModel.serviceFieldError
                        )

                        Text(viewModel.footerCaption)
                            .font(.caption)
                            .foregroundStyle(NeonTheme.onSurfaceVariant)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(L10n.appleRegistrationNote)
                            .font(.caption)
                            .foregroundStyle(NeonTheme.onSurfaceVariant)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        createButton
                    }
                    .padding(24)
                }

                RegistrationBackButton(action: onBack)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .onAppear { applySmlerInviteCodeIfNeeded() }
        .onChange(of: smlerInviteCoordinator.pendingRegistrationCode) { _, code in
            guard role == .passenger, let code else { return }
            viewModel.applyPrefillServiceCode(code)
        }
    }

    private func applySmlerInviteCodeIfNeeded() {
        guard role == .passenger,
              let code = smlerInviteCoordinator.pendingRegistrationCode else { return }
        viewModel.applyPrefillServiceCode(code)
        smlerInviteCoordinator.consumeRegistrationInvite()
    }

    private var serviceFieldBinding: Binding<String> {
        Binding(
            get: { viewModel.serviceField },
            set: { viewModel.updateServiceField($0) }
        )
    }

    private var canTapAppleSignIn: Bool {
        !store.isLoading && !authService.isLoading && !viewModel.isLoading
    }

    private var createButton: some View {
        SignInWithAppleButton(
            title: L10n.registerWithApple,
            isLoading: store.isLoading || authService.isLoading || viewModel.isLoading
        ) {
            guard viewModel.validateBeforeAppleSignIn() else { return }
            Task {
                await viewModel.createAccount(
                    authService: authService,
                    store: store,
                    session: session
                )
            }
        }
        .disabled(!canTapAppleSignIn)
        .opacity(canTapAppleSignIn ? 1 : 0.5)
    }
}

#Preview("Sürücü") {
    RegistrationFormView(role: .driver, onBack: {})
        .environment(ShuttleStore())
        .environment(UserSession.shared)
        .environment(AuthService.shared)
        .environment(SmlerInviteCoordinator())
}

#Preview("Yolcu") {
    RegistrationFormView(role: .passenger, onBack: {})
        .environment(ShuttleStore())
        .environment(UserSession.shared)
        .environment(AuthService.shared)
        .environment(SmlerInviteCoordinator())
}
