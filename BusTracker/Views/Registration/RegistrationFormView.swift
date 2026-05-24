import SwiftUI

struct RegistrationFormView: BaseView {
    @Environment(ShuttleStore.self) private var store
    @Environment(UserSession.self) private var session
    @Environment(AuthService.self) private var authService

    let role: MemberRole
    let onBack: () -> Void

    @State var viewModel: RegistrationFormViewModel

    init(role: MemberRole, onBack: @escaping () -> Void) {
        self.role = role
        self.onBack = onBack
        _viewModel = State(initialValue: RegistrationFormViewModel(role: role))
    }

    func content() -> some View {
        ZStack(alignment: .bottom) {
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
                            NeonFormField(title: "Adınız", text: $viewModel.name, prompt: viewModel.namePrompt)
                            NeonPhoneFormField(title: "Telefon", text: $viewModel.phone)
                            NeonFormField(
                                title: viewModel.serviceFieldTitle,
                                text: $viewModel.serviceField,
                                prompt: viewModel.serviceFieldPrompt
                            )

                            Text(viewModel.footerCaption)
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

            if viewModel.showOTPVerification {
                ZStack(alignment: .bottom) {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .onTapGesture { dismissOTP() }

                    OTPVerificationView(
                        formattedPhone: viewModel.formattedPhone,
                        otpCode: $viewModel.otpCode,
                        isLoading: store.isLoading || authService.isLoading,
                        onSubmit: {
                            Task {
                                await viewModel.verifyAndCreateAccount(
                                    authService: authService,
                                    store: store,
                                    session: session
                                )
                            }
                        },
                        onResend: {
                            Task { await viewModel.beginAccountCreation(authService: authService) }
                        },
                        onDismiss: dismissOTP
                    )
                }
                .ignoresSafeArea(edges: .bottom)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.28), value: viewModel.showOTPVerification)
    }

    private func dismissOTP() {
        viewModel.showOTPVerification = false
        viewModel.otpCode = ""
    }

    private var createButton: some View {
        Button {
            Task { await viewModel.beginAccountCreation(authService: authService) }
        } label: {
            Group {
                if store.isLoading || authService.isLoading {
                    ProgressView().tint(NeonTheme.onSurface)
                } else {
                    HStack(spacing: 8) {
                        Text("HESABI OLUŞTUR")
                            .tracking(1.2)
                        Image(systemName: "arrow.up.right")
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(NeonPrimaryButtonStyle(tint: viewModel.accent))
        .disabled(!viewModel.canSubmit || store.isLoading || authService.isLoading)
        .opacity(viewModel.canSubmit ? 1 : 0.5)
    }
}

#Preview("Sürücü") {
    RegistrationFormView(role: .driver, onBack: {})
        .environment(ShuttleStore())
        .environment(UserSession.shared)
        .environment(AuthService.shared)
}

#Preview("Yolcu") {
    RegistrationFormView(role: .passenger, onBack: {})
        .environment(ShuttleStore())
        .environment(UserSession.shared)
        .environment(AuthService.shared)
}
