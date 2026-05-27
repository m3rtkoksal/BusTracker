import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

@MainActor
@Observable
final class LoginViewModel: BaseViewModel {
    var phone = ""
    var otpCode = ""
    var codeSent = false

    let onRegisterTapped: () -> Void

    init(onRegisterTapped: @escaping () -> Void) {
        self.onRegisterTapped = onRegisterTapped
        super.init()
        title = "Giriş"
        navigationBarStyle = .auth
    }

    var canSendCode: Bool {
        phone.filter(\.isNumber).count >= 10
    }

    var canLogin: Bool {
        otpCode.count >= 6
    }

    func sendCode(authService: AuthService) async {
        do {
            try await authService.sendOTP(rawPhone: phone)
            codeSent = true
        } catch {
            showError(error.localizedDescription)
        }
    }

    func login(authService: AuthService, store: ShuttleStore, session: UserSession) async {
        setLoading(true, message: "Giriş yapılıyor...")
        defer { setLoading(false) }

        do {
            try await authService.verifyOTP(code: otpCode)
            guard let userID = authService.currentUserID else { return }

            if let profile = try await store.fetchUserProfile(userID: userID) {
                session.save(profile)
                await NotificationService.shared.requestPermissionAndRegister()

                let groupID = profile.groupID ?? profile.primaryGroupID

                if !groupID.isEmpty {
                    await NotificationService.shared.saveTokenToProfile(
                        groupID: groupID,
                        memberID: profile.memberID
                    )
                } else {
                    showError("Profil bilgileri eksik. Lütfen tekrar giriş yapın.")
                    try? authService.signOut()
                    codeSent = false
                    otpCode = ""
                }
            } else {
                showError("Bu numarayla kayıtlı hesap bulunamadı. Hesap oluşturun.")
                try? authService.signOut()
                codeSent = false
                otpCode = ""
            }
        } catch {
            showError(error.localizedDescription)
        }
    }

    func resetPhoneEntry() {
        codeSent = false
        otpCode = ""
    }

    var formattedPhone: String {
        AuthService.displayFormat(AuthService.formatPhone(phone))
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
                    // Hero matching Android Login + iOS NeonRegistrationHero style
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

                            Image(systemName: "person.badge.key.fill")
                                .font(.system(size: 34, weight: .medium))
                                .foregroundStyle(NeonTheme.secondary)
                                .shadow(color: NeonTheme.secondary.opacity(0.6), radius: 8)
                        }

                        Text("Giriş Yap")
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundStyle(NeonTheme.onSurface)

                        HStack(spacing: 8) {
                            Rectangle()
                                .fill(NeonTheme.onSurfaceVariant.opacity(0.3))
                                .frame(width: 32, height: 1)
                            Text("Mevcut hesabınıza telefon numaranızla giriş yapın.")
                                .font(.subheadline)
                                .foregroundStyle(NeonTheme.onSurfaceVariant)
                                .multilineTextAlignment(.center)
                            Rectangle()
                                .fill(NeonTheme.onSurfaceVariant.opacity(0.3))
                                .frame(width: 32, height: 1)
                        }
                        .padding(.horizontal, 8)
                    }
                    .padding(.top, 12)

                    // Glass form card
                    NeonGlassCard(accent: NeonTheme.secondary) {
                        VStack(spacing: 20) {
                            // Phone input with +90 (Android style)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Telefon")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(NeonTheme.onSurface)

                                HStack(spacing: 10) {
                                    Text("+90")
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(NeonTheme.secondary)

                                    TextField("532 123 45 67", text: $viewModel.phone)
                                        .keyboardType(.phonePad)
                                        .textContentType(.telephoneNumber)
                                        .font(.body)
                                        .foregroundStyle(NeonTheme.onSurface)
                                        .onChange(of: viewModel.phone) { _, newValue in
                                            viewModel.phone = Self.normalizeLocalDigits(newValue)
                                        }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(NeonTheme.surfaceBright.opacity(0.85))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(NeonTheme.outline.opacity(0.4), lineWidth: 1)
                                )
                            }

                            Text("Hesabınız varsa doğrulama kodu ile giriş yapabilirsiniz.")
                                .font(.caption)
                                .foregroundStyle(NeonTheme.onSurfaceVariant)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            // Main action button - filled "yeşil" (secondary) background like before,
                            // refined thin text, high contrast black text on bright fill
                            Button {
                                Task { await viewModel.sendCode(authService: authService) }
                            } label: {
                                HStack(spacing: 8) {
                                    if authService.isLoading {
                                        ProgressView()
                                            .tint(.black)
                                    } else {
                                        Text("GİRİŞ YAP")
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .tracking(1.5)
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                }
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(NeonTheme.secondary)
                            )
                            .shadow(color: NeonTheme.secondary.opacity(0.4), radius: 12, y: 4)
                            .scaleEffect(1.0)
                            .disabled(!viewModel.canSendCode || authService.isLoading)
                            .opacity(viewModel.canSendCode ? 1 : 0.55)
                        }
                        .padding(24)
                    }

                    // Bottom link
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
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .overlay {
            // Beautiful OTP sheet overlay (same as registration)
            if viewModel.codeSent {
                ZStack(alignment: .bottom) {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                        .onTapGesture {
                            // optional: allow tap outside to cancel OTP
                            // viewModel.resetPhoneEntry()
                        }

                    OTPVerificationView(
                        formattedPhone: viewModel.formattedPhone,
                        otpCode: $viewModel.otpCode,
                        isLoading: authService.isLoading || viewModel.isLoading,
                        onSubmit: {
                            Task {
                                await viewModel.login(authService: authService, store: store, session: session)
                            }
                        },
                        onResend: {
                            Task { await viewModel.sendCode(authService: authService) }
                        },
                        onDismiss: { viewModel.resetPhoneEntry() },
                        submitButtonTitle: "ONAYLA"
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .ignoresSafeArea(edges: .bottom)
                .animation(.easeInOut(duration: 0.28), value: viewModel.codeSent)
            }
        }
    }

    private static func normalizeLocalDigits(_ raw: String) -> String {
        var digits = raw.filter(\.isNumber)
        if digits.hasPrefix("90"), digits.count > 10 {
            digits = String(digits.dropFirst(2))
        } else if digits.hasPrefix("0"), digits.count > 10 {
            digits = String(digits.dropFirst())
        }
        return String(digits.prefix(10))
    }
}



