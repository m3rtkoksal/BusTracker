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
        case .notSignedIn: "Oturum açık değil."
        case .profileNotFound: "Kullanıcı profili bulunamadı."
        case .firebaseNotReady: "Firebase henüz hazır değil. Lütfen tekrar deneyin."
        case .appleSignInFailed(let message): message
        case .missingAppleUserID: "Apple hesap kimliği alınamadı."
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
        throw AuthServiceError.appleSignInFailed("Apple ile giriş yalnızca iOS'ta desteklenir.")
#endif
    }

    func signOut() throws {
        ensureConfigured()
        try Auth.auth().signOut()
        appleUserID = nil
    }

    func deleteCurrentUser() async throws {
        await waitUntilReady()
        guard let user = Auth.auth().currentUser else {
            throw AuthServiceError.notSignedIn
        }
        try await user.delete()
        appleUserID = nil
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
