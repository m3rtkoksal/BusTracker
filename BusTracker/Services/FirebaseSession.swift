import FirebaseAuth
import FirebaseCore
import Foundation
#if os(iOS) || os(visionOS)
import UIKit
#endif

@MainActor
@Observable
final class FirebaseSession {
    static let shared = FirebaseSession()

    private(set) var isReady = false
    private(set) var error: FirebaseBootstrapError?

    private init() {}

    func bootstrap() async {
        guard !isReady else { return }
        error = nil

        FirebaseManager.configureIfNeeded()

        guard FirebaseApp.app() != nil else {
            error = .missingConfiguration
            return
        }

#if os(iOS) || os(visionOS)
        if !FirebaseAuthLaunch.isReady {
            FirebaseAuthLaunch.start(in: UIApplication.shared) {}
        }
#endif

        await AuthService.shared.waitUntilReady()
        isReady = true
        error = nil
    }

    func ensureAuthenticated() async throws {
        if !isReady {
            await bootstrap()
        }

        guard isReady else {
            throw error ?? FirebaseBootstrapError.authenticationFailed(L10n.firebaseNotReadyShort)
        }

        guard Auth.auth().currentUser != nil else {
            throw FirebaseBootstrapError.authenticationFailed(L10n.signInWithPhone)
        }
    }
}
