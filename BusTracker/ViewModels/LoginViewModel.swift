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
                await NotificationService.shared.saveTokenToProfile(
                    groupID: profile.groupID,
                    memberID: profile.memberID
                )
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
        VStack(spacing: 24) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.blue)

            Text(viewModel.codeSent ? "Doğrulama kodunu girin" : "Giriş yapın")
                .font(.title3.bold())

            if viewModel.codeSent {
                otpStep
            } else {
                phoneStep
            }

            Spacer()

            Button("Hesap oluştur", action: viewModel.onRegisterTapped)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(24)
    }

    private var phoneStep: some View {
        VStack(spacing: 16) {
            PhoneFormField(title: "Telefon", text: $viewModel.phone)

            Button {
                Task { await viewModel.sendCode(authService: authService) }
            } label: {
                if authService.isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Text("Kod Gönder").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!viewModel.canSendCode || authService.isLoading)
        }
    }

    private var otpStep: some View {
        VStack(spacing: 16) {
            Text("\(viewModel.formattedPhone) numarasına kod gönderildi.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            FormField(title: "Doğrulama kodu", text: $viewModel.otpCode, prompt: "6 haneli kod", keyboard: .numberPad)

            Button {
                Task { await viewModel.login(authService: authService, store: store, session: session) }
            } label: {
                Text("Giriş Yap").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!viewModel.canLogin || authService.isLoading || viewModel.isLoading)

            Button("Numarayı değiştir", action: viewModel.resetPhoneEntry)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#if canImport(UIKit)
struct FormField: View {
    let title: String
    @Binding var text: String
    let prompt: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.weight(.medium))
            TextField(prompt, text: $text)
                .keyboardType(keyboard)
                .textFieldStyle(.roundedBorder)
        }
    }
}

struct PhoneFormField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.weight(.medium))
            HStack(spacing: 6) {
                Text("+90")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField("5321234567", text: $text)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .onChange(of: text) { _, newValue in
                        text = Self.normalizeLocalDigits(newValue)
                    }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color(.systemGray4), lineWidth: 0.5)
            )
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
#else
struct FormField: View {
    let title: String
    @Binding var text: String
    let prompt: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.weight(.medium))
            TextField(prompt, text: $text).textFieldStyle(.roundedBorder)
        }
    }
}

struct PhoneFormField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.weight(.medium))
            HStack(spacing: 6) {
                Text("+90").foregroundStyle(.secondary)
                TextField("5321234567", text: $text)
                    .onChange(of: text) { _, newValue in
                        text = String(newValue.filter(\.isNumber).prefix(10))
                    }
            }
            .textFieldStyle(.roundedBorder)
        }
    }
}
#endif
