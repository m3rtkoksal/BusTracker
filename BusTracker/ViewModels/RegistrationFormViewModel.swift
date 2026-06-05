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
        title = L10n.createAccountTitle
        navSubtitleStyle = .hidden
        usesLargeTitle = false
        hidesNavigationBar = true
        navigationBarStyle = .neonAuth
        embedsInNavigationStack = false
    }

    var heroTitle: String {
        role == .driver ? L10n.driverRegistration : L10n.passengerRegistration
    }

    var heroSubtitle: String {
        role == .driver
            ? L10n.driverRegistrationSubtitle
            : L10n.passengerRegistrationSubtitle
    }

    var heroIcon: String {
        role == .driver ? "steeringwheel" : "person.fill"
    }

    var accent: Color {
        role == .driver ? NeonTheme.primary : NeonTheme.secondary
    }

    var serviceFieldTitle: String {
        role == .driver ? L10n.serviceNameField : L10n.serviceCodeField
    }

    var serviceFieldPrompt: String {
        role == .driver ? L10n.serviceNameExample : L10n.serviceCodeExample
    }

    var namePrompt: String {
        role == .driver ? L10n.nameExampleDriver : L10n.nameExamplePassenger
    }

    var footerCaption: String {
        role == .driver
            ? L10n.driverLocationFooter
            : L10n.passengerLocationFooter
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
            showError(L10n.enterNameToRegister)
            return false
        }
        let trimmedService = serviceField.trimmingCharacters(in: .whitespacesAndNewlines)
        if role == .passenger {
            if trimmedService.isEmpty {
                serviceFieldError = L10n.enterServiceCode
                return false
            }
            if trimmedService.count < 4 {
                serviceFieldError = L10n.serviceCodeMinLength
                return false
            }
        } else if trimmedService.isEmpty {
            serviceFieldError = L10n.enterServiceName
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
                showSuccess(L10n.driverAccountCreated)
            } else {
                profile = try await store.joinGroup(code: serviceField, passengerName: name)
                showSuccess(L10n.joinedShuttle)
            }

            session.save(profile)
            let groupID = profile.primaryGroupID.isEmpty
                ? (profile.groupID ?? "")
                : profile.primaryGroupID
            await NotificationService.shared.syncTokenIfAuthorized(
                groupID: groupID,
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
            return error.errorDescription ?? L10n.shuttleCodeNotFound
        case .invalidInput(let message):
            return message
        case .alreadyInGroup:
            return error.errorDescription ?? L10n.alreadyInShuttle
        case .notAuthenticated:
            return error.errorDescription ?? L10n.signInRequired
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
