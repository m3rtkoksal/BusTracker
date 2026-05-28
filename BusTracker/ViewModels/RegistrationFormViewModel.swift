import SwiftUI

@MainActor
@Observable
final class RegistrationFormViewModel: BaseViewModel {
    let role: MemberRole

    var name = ""
    var serviceField = ""

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
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        let trimmed = serviceField.trimmingCharacters(in: .whitespacesAndNewlines)
        return role == .driver ? !trimmed.isEmpty : serviceField.count >= 4
    }

    func createAccount(
        authService: AuthService,
        store: ShuttleStore,
        session: UserSession
    ) async {
        authService.setCompletingRegistration(true)
        defer { authService.setCompletingRegistration(false) }

        do {
            await NotificationService.shared.requestPermissionIfNeeded()
            let appleResult = try await authService.signInWithApple()

            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let suggested = appleResult.displayName {
                name = suggested
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
            showError(userFacingMessage(for: error))
        } catch {
            showError(userFacingMessage(for: error))
            if session.profile == nil {
                try? authService.signOut()
            }
        }
    }

    private func userFacingMessage(for error: Error) -> String {
        AuthErrorMessage.log(error, context: "registration")
        if let authError = error as? AuthServiceError {
            return authError.localizedDescription
        }
        return AuthErrorMessage.message(for: error)
    }
}
