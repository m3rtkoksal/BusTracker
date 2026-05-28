import FirebaseAuth
import FirebaseCore
import Foundation

enum AuthServiceError: LocalizedError {
    case notSignedIn
    case invalidPhone
    case missingVerificationID
    case profileNotFound
    case firebaseNotReady

    var errorDescription: String? {
        switch self {
        case .notSignedIn: "Oturum açık değil."
        case .invalidPhone: "Geçerli bir telefon numarası girin."
        case .missingVerificationID: "Önce doğrulama kodu isteyin."
        case .profileNotFound: "Kullanıcı profili bulunamadı."
        case .firebaseNotReady: "Firebase henüz hazır değil. Lütfen tekrar deneyin."
        }
    }
}

@MainActor
@Observable
final class AuthService {
    static let shared = AuthService()

    private(set) var isSignedIn = false
    private(set) var phoneNumber: String?
    private(set) var verifiedPhoneNumber: String?
    private(set) var isLoading = false
    private(set) var isCompletingRegistration = false

    var displayPhoneNumber: String? {
        phoneNumber ?? verifiedPhoneNumber
    }

    private var verificationID: String?
    private var authListener: AuthStateDidChangeListenerHandle?
    private var didConfigureAuth = false

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

        configurePhoneAuthForTesting()

        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.isSignedIn = user != nil
                self?.phoneNumber = user?.phoneNumber
            }
        }
        isSignedIn = Auth.auth().currentUser != nil
        phoneNumber = Auth.auth().currentUser?.phoneNumber
    }

    func waitUntilReady() async {
        #if os(iOS) || os(visionOS)
        await FirebaseAuthLaunch.waitUntilReady()
        #endif
        ensureConfigured()
    }

    /// Simülatörde test numaraları için APNs/reCAPTCHA doğrulamasını atlar.
    private func configurePhoneAuthForTesting() {
        #if DEBUG
        Auth.auth().settings?.isAppVerificationDisabledForTesting = true
        #endif
    }

    func sendOTP(rawPhone: String) async throws {
        await waitUntilReady()
        guard FirebaseApp.app() != nil else { throw AuthServiceError.firebaseNotReady }

        configurePhoneAuthForTesting()

        let formatted = Self.formatPhone(rawPhone)
        guard formatted.count >= 12 else { throw AuthServiceError.invalidPhone }

        isLoading = true
        defer { isLoading = false }

        verifiedPhoneNumber = formatted

        let provider = PhoneAuthProvider.provider()
        verificationID = try await withCheckedThrowingContinuation { continuation in
#if os(iOS) || os(visionOS)
            let uiDelegate: AuthUIDelegate? = {
                #if DEBUG && targetEnvironment(simulator)
                return nil
                #else
                return PhoneAuthUIDelegate.shared
                #endif
            }()
            provider.verifyPhoneNumber(formatted, uiDelegate: uiDelegate) { id, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let id else {
                    continuation.resume(throwing: AuthServiceError.missingVerificationID)
                    return
                }
                continuation.resume(returning: id)
            }
#else
            provider.verifyPhoneNumber(formatted, uiDelegate: nil) { id, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let id else {
                    continuation.resume(throwing: AuthServiceError.missingVerificationID)
                    return
                }
                continuation.resume(returning: id)
            }
#endif
        }
    }

    func verifyOTP(code: String) async throws {
        await waitUntilReady()
        guard FirebaseApp.app() != nil else { throw AuthServiceError.firebaseNotReady }
        guard let verificationID else { throw AuthServiceError.missingVerificationID }

        isLoading = true
        defer { isLoading = false }

        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: code.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        _ = try await Auth.auth().signIn(with: credential)
        phoneNumber = Auth.auth().currentUser?.phoneNumber ?? verifiedPhoneNumber
        self.verificationID = nil
    }

    func signOut() throws {
        ensureConfigured()
        try Auth.auth().signOut()
        verificationID = nil
        verifiedPhoneNumber = nil
    }

    /// Mevcut kullanıcının Firebase Auth hesabını siler.
    /// Güvenlik için çağrıdan önce yeniden doğrulama (OTP) yapılmış olmalıdır.
    func deleteCurrentUser() async throws {
        await waitUntilReady()
        guard let user = Auth.auth().currentUser else {
            throw AuthServiceError.notSignedIn
        }
        try await user.delete()
    }

    func setCompletingRegistration(_ value: Bool) {
        isCompletingRegistration = value
    }

    static func displayFormat(_ e164: String) -> String {
        let digits = e164.filter(\.isNumber)
        guard digits.count >= 12, digits.hasPrefix("90") else { return e164 }
        let local = String(digits.dropFirst(2))
        guard local.count == 10 else { return e164 }
        let area = local.prefix(3)
        let mid = local.dropFirst(3).prefix(3)
        let end = local.suffix(4)
        return "+90 \(area) \(mid) \(end.prefix(2)) \(end.suffix(2))"
    }

    static func formatPhone(_ raw: String) -> String {
        let digits = raw.filter(\.isNumber)
        if digits.hasPrefix("90") && digits.count == 12 {
            return "+\(digits)"
        }
        if digits.hasPrefix("0") && digits.count == 11 {
            return "+9\(digits)"
        }
        if digits.count == 10 {
            return "+90\(digits)"
        }
        if raw.hasPrefix("+") {
            return "+\(digits)"
        }
        return "+\(digits)"
    }
}
