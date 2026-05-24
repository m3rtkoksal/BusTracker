import FirebaseAuth
import FirebaseCore
import Foundation

@MainActor
@Observable
final class FirebaseSession {
    static let shared = FirebaseSession()

    private(set) var isReady = false
    private(set) var error: FirebaseBootstrapError?

    private init() {}

    func bootstrap() async {
        guard !isReady else { return }

        FirebaseManager.configureIfNeeded()

        guard FirebaseApp.app() != nil else {
            error = .missingConfiguration
            return
        }

        await AuthService.shared.waitUntilReady()
        isReady = true
        error = nil
    }

    func ensureAuthenticated() async throws {
        if !isReady {
            await bootstrap()
        }

        guard isReady else {
            throw error ?? FirebaseBootstrapError.authenticationFailed("Firebase hazır değil.")
        }

        guard Auth.auth().currentUser != nil else {
            throw FirebaseBootstrapError.authenticationFailed("Telefon ile giriş yapın.")
        }
    }
}
