import FirebaseAuth
import FirebaseCore
import Foundation

enum AuthServiceError: LocalizedError {
    case notSignedIn
    case profileNotFound
    case firebaseNotReady
    case appleSignInFailed(String)
    case missingAppleUserID

    var errorDescription: String? {
        switch self {
        case .notSignedIn: L10n.notSignedIn
        case .profileNotFound: L10n.userProfileNotFound
        case .firebaseNotReady: L10n.firebaseNotReady
        case .appleSignInFailed(let message): message
        case .missingAppleUserID: L10n.appleUserIDUnavailable
        }
    }
}

@MainActor
@Observable
final class AuthService {
    static let shared = AuthService()

    private(set) var isSignedIn = false
    private(set) var appleUserID: String?
    private(set) var isLoading = false
    private(set) var isCompletingRegistration = false

    private var authListener: AuthStateDidChangeListenerHandle?
    private var didConfigureAuth = false
#if os(iOS) || os(visionOS)
    private let appleSignIn = AppleSignInCoordinator()
#endif

    private init() {}

    var currentUserID: String? {
        guard FirebaseApp.app() != nil else { return nil }
        #if os(iOS) || os(visionOS)
        guard FirebaseAuthLaunch.isReady else { return nil }
        #endif
        return Auth.auth().currentUser?.uid
    }

    func ensureConfigured() {
        FirebaseManager.configureIfNeeded()
        guard FirebaseApp.app() != nil else { return }
        #if os(iOS) || os(visionOS)
        guard FirebaseAuthLaunch.isReady else { return }
        #endif
        guard !didConfigureAuth else { return }
        didConfigureAuth = true

        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.isSignedIn = user != nil
                self?.appleUserID = Self.resolveAppleUserID(from: user)
            }
        }
        isSignedIn = Auth.auth().currentUser != nil
        appleUserID = Self.resolveAppleUserID(from: Auth.auth().currentUser)
    }

    func waitUntilReady() async {
        #if os(iOS) || os(visionOS)
        await FirebaseAuthLaunch.waitUntilReady()
        #endif
        ensureConfigured()
    }

    func signInWithApple() async throws -> AppleSignInResult {
        await waitUntilReady()
        guard FirebaseApp.app() != nil else { throw AuthServiceError.firebaseNotReady }

        isLoading = true
        defer { isLoading = false }

#if os(iOS) || os(visionOS)
        do {
            let result = try await appleSignIn.signIn()
            appleUserID = result.appleUserID
            return result
        } catch let error as AppleSignInError {
            throw error
        } catch {
            AuthErrorMessage.log(error, context: "signInWithApple")
            throw AuthServiceError.appleSignInFailed(AuthErrorMessage.message(for: error))
        }
#else
        throw AuthServiceError.appleSignInFailed(L10n.appleSignInIOSOnly)
#endif
    }

    func signOut() throws {
        ensureConfigured()
        try Auth.auth().signOut()
        appleUserID = nil
    }

    /// Firebase Auth hesabını siler. Zaten silinmişse `true` döner.
    @discardableResult
    func removeAccountIfPossible() async -> Bool {
        await waitUntilReady()
        guard let user = Auth.auth().currentUser else {
            clearSignedInState()
            return true
        }

        let firstAttempt = await deleteAuthUser(user)
        if firstAttempt.succeeded {
            return true
        }

#if os(iOS) || os(visionOS)
        if firstAttempt.needsRecentLogin,
           await reauthenticateWithAppleForAccountDeletion(),
           let refreshedUser = Auth.auth().currentUser {
            let secondAttempt = await deleteAuthUser(refreshedUser)
            if secondAttempt.succeeded {
                return true
            }
        }
#endif

        return Auth.auth().currentUser == nil
    }

    private struct DeleteAuthUserResult {
        let succeeded: Bool
        let needsRecentLogin: Bool
    }

    private func deleteAuthUser(_ user: User) async -> DeleteAuthUserResult {
        do {
            try await user.delete()
            clearSignedInState()
            return DeleteAuthUserResult(succeeded: true, needsRecentLogin: false)
        } catch {
            AuthErrorMessage.log(error, context: "deleteAccount")
            if Auth.auth().currentUser == nil {
                clearSignedInState()
                return DeleteAuthUserResult(succeeded: true, needsRecentLogin: false)
            }
            let nsError = error as NSError
            let needsRecentLogin = nsError.domain == AuthErrorDomain
                && nsError.code == AuthErrorCode.requiresRecentLogin.rawValue
            return DeleteAuthUserResult(succeeded: false, needsRecentLogin: needsRecentLogin)
        }
    }

#if os(iOS) || os(visionOS)
    /// Hesap silme öncesi Apple oturumunu yeniler.
    func reauthenticateForAccountDeletion() async throws {
        await waitUntilReady()
        do {
            let result = try await appleSignIn.reauthenticate()
            appleUserID = result.appleUserID
            isSignedIn = Auth.auth().currentUser != nil
        } catch let error as AppleSignInError {
            throw error
        } catch {
            AuthErrorMessage.log(error, context: "reauthenticateForDelete")
            throw AuthServiceError.appleSignInFailed(AuthErrorMessage.message(for: error))
        }
    }
#endif

#if os(iOS) || os(visionOS)
    private func reauthenticateWithAppleForAccountDeletion() async -> Bool {
        do {
            try await reauthenticateForAccountDeletion()
            return true
        } catch let error as AppleSignInError {
            if case .cancelled = error { return false }
            return false
        } catch {
            return false
        }
    }
#endif

    private func clearSignedInState() {
        appleUserID = nil
        isSignedIn = false
    }

    func deleteCurrentUser() async throws {
        let removed = await removeAccountIfPossible()
        if !removed {
            throw AuthServiceError.appleSignInFailed(L10n.reauthRequiredToDelete)
        }
    }

    func setCompletingRegistration(_ value: Bool) {
        isCompletingRegistration = value
    }

    static func resolveAppleUserID(from user: User?) -> String? {
        guard let user else { return nil }
        if let appleProvider = user.providerData.first(where: { $0.providerID == "apple.com" }) {
            return appleProvider.uid
        }
        return user.uid
    }
}
