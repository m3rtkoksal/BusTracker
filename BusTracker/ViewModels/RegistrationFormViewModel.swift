import SwiftUI

@MainActor
@Observable
final class RegistrationFormViewModel: BaseViewModel {
    let role: MemberRole

    var name = ""
    var serviceField = ""
    var serviceFieldError: String?

    init(role: MemberRole) {
        self.role = role
        super.init()
        title = "Hesap Oluştur"
        navSubtitleStyle = .hidden
        usesLargeTitle = false
        hidesNavigationBar = true
        navigationBarStyle = .neonAuth
        embedsInNavigationStack = false
    }

    var heroTitle: String {
        role == .driver ? "Sürücü Kaydı" : "Yolcu Kaydı"
    }

    var heroSubtitle: String {
        role == .driver
            ? "Servisinizi oluşturun, yolcularınız sizi takip etsin."
            : "Servis kodunuzla katılın, haritadan takip edin."
    }

    var heroIcon: String {
        role == .driver ? "steeringwheel" : "person.fill"
    }

    var accent: Color {
        role == .driver ? NeonTheme.primary : NeonTheme.secondary
    }

    var serviceFieldTitle: String {
        role == .driver ? "Servis adı" : "Servis kodu"
    }

    var serviceFieldPrompt: String {
        role == .driver ? "Örn. Kadıköy Servisi" : "Sürücünün verdiği 6 haneli kod"
    }

    var namePrompt: String {
        role == .driver ? "Örn. Ahmet" : "Örn. Ayşe"
    }

    var footerCaption: String {
        role == .driver
            ? "Konum paylaşımı yalnızca sürücü hesabında açıktır."
            : "Yolcu hesabında konum paylaşımı yoktur."
    }

    var canSubmit: Bool {
        Self.isRegistrationFormComplete(name: name, serviceField: serviceField, role: role)
    }

    func updateServiceField(_ value: String) {
        serviceField = role == .passenger ? value.uppercased() : value
        serviceFieldError = nil
    }

    func applyPrefillServiceCode(_ code: String) {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard normalized.count >= 4 else { return }
        serviceField = normalized
        serviceFieldError = nil
    }

    /// Apple kayıt öncesi yerel doğrulama; hata servis alanı altında gösterilir.
    func validateBeforeAppleSignIn() -> Bool {
        serviceFieldError = nil
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            showError("Kayıt için adınızı girin.")
            return false
        }
        let trimmedService = serviceField.trimmingCharacters(in: .whitespacesAndNewlines)
        if role == .passenger {
            if trimmedService.isEmpty {
                serviceFieldError = "Servis kodu girmedin."
                return false
            }
            if trimmedService.count < 4 {
                serviceFieldError = "Servis kodu en az 4 karakter olmalı."
                return false
            }
        } else if trimmedService.isEmpty {
            serviceFieldError = "Servis adı girmedin."
            return false
        }
        return true
    }

    func createAccount(
        authService: AuthService,
        store: ShuttleStore,
        session: UserSession
    ) async {
        guard canSubmit else { return }

        authService.setCompletingRegistration(true)
        defer { authService.setCompletingRegistration(false) }

        do {
            await NotificationService.shared.requestPermissionIfNeeded()
            let appleResult = try await authService.signInWithApple()

            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let suggested = appleResult.displayName {
                name = suggested
            }

            if role == .passenger {
                do {
                    try await store.validatePassengerGroupCode(serviceField)
                } catch let error as ShuttleStoreError {
                    serviceFieldError = serviceFieldErrorMessage(for: error)
                    try? authService.signOut()
                    return
                }
            }

            let profile: UserProfile
            if role == .driver {
                profile = try await store.createGroup(name: serviceField, driverName: name)
                showSuccess("Servis hesabınız oluşturuldu.")
            } else {
                profile = try await store.joinGroup(code: serviceField, passengerName: name)
                showSuccess("Servise katıldınız.")
            }

            session.save(profile)
            await NotificationService.shared.requestPermissionIfNeeded()
            await NotificationService.shared.saveTokenToProfile(
                groupID: profile.groupID ?? "",
                memberID: profile.memberID
            )
        } catch let error as AppleSignInError {
            if case .cancelled = error { return }
            if !applyPassengerServiceFieldError(error) {
                showError(userFacingMessage(for: error))
            }
            if session.profile == nil {
                try? authService.signOut()
            }
        } catch {
            if !applyPassengerServiceFieldError(error) {
                showError(userFacingMessage(for: error))
            }
            if session.profile == nil {
                try? authService.signOut()
            }
        }
    }

    static func isRegistrationFormComplete(
        name: String,
        serviceField: String,
        role: MemberRole
    ) -> Bool {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        let trimmedService = serviceField.trimmingCharacters(in: .whitespacesAndNewlines)
        if role == .driver {
            return !trimmedService.isEmpty
        }
        return trimmedService.count >= 4
    }

    private func serviceFieldErrorMessage(for error: ShuttleStoreError) -> String {
        switch error {
        case .groupNotFound:
            return error.errorDescription ?? "Bu servis kodu bulunamadı."
        case .invalidInput(let message):
            return message
        case .alreadyInGroup:
            return error.errorDescription ?? "Zaten bir servise kayıtlısınız."
        case .notAuthenticated:
            return error.errorDescription ?? "Giriş yapmanız gerekiyor."
        }
    }

    @discardableResult
    private func applyPassengerServiceFieldError(_ error: Error) -> Bool {
        guard role == .passenger, let storeError = error as? ShuttleStoreError else { return false }
        serviceFieldError = serviceFieldErrorMessage(for: storeError)
        return true
    }

    private func userFacingMessage(for error: Error) -> String {
        AuthErrorMessage.log(error, context: "registration")
        if let authError = error as? AuthServiceError {
            return authError.localizedDescription
        }
        return AuthErrorMessage.message(for: error)
    }
}
