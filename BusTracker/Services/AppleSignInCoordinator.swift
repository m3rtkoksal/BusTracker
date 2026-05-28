#if os(iOS) || os(visionOS)
import AuthenticationServices
import CryptoKit
import FirebaseAuth
import UIKit

enum AppleSignInError: LocalizedError, Equatable {
    case missingCredential
    case missingIdentityToken
    case cancelled

    var errorDescription: String? {
        switch self {
        case .missingCredential: "Apple giriş bilgisi alınamadı."
        case .missingIdentityToken: "Apple kimlik doğrulaması tamamlanamadı."
        case .cancelled: "Apple ile giriş iptal edildi."
        }
    }
}

struct AppleSignInResult {
    let appleUserID: String
    let displayName: String?
    let email: String?
}

@MainActor
final class AppleSignInCoordinator: NSObject {
    private var continuation: CheckedContinuation<AppleSignInResult, Error>?
    private var currentNonce: String?
    private weak var presentationWindow: UIWindow?

    func signIn() async throws -> AppleSignInResult {
        presentationWindow = Self.keyWindow()
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let nonce = Self.randomNonce()
            currentNonce = nonce

            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = Self.sha256(nonce)

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    private static func keyWindow() -> UIWindow {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow } ?? UIWindow()
    }

    private func finish(_ result: Result<AppleSignInResult, Error>) {
        continuation?.resume(with: result)
        continuation = nil
        currentNonce = nil
    }

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in UInt8.random(in: 0...255) }
            randoms.forEach { random in
                if remaining == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                finish(.failure(AppleSignInError.missingCredential))
                return
            }
            guard let nonce = currentNonce else {
                finish(.failure(AppleSignInError.missingCredential))
                return
            }
            guard let tokenData = appleIDCredential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                finish(.failure(AppleSignInError.missingIdentityToken))
                return
            }

            let credential = OAuthProvider.appleCredential(
                withIDToken: idToken,
                rawNonce: nonce,
                fullName: appleIDCredential.fullName
            )

            do {
                _ = try await Auth.auth().signIn(with: credential)
                _ = try await Auth.auth().currentUser?.getIDToken(forcingRefresh: true)

                let displayName = Self.formattedName(from: appleIDCredential.fullName)
                finish(.success(AppleSignInResult(
                    appleUserID: appleIDCredential.user,
                    displayName: displayName,
                    email: appleIDCredential.email
                )))
            } catch {
                finish(.failure(error))
            }
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            let nsError = error as NSError
            if nsError.domain == ASAuthorizationError.errorDomain,
               nsError.code == ASAuthorizationError.canceled.rawValue {
                finish(.failure(AppleSignInError.cancelled))
            } else {
                finish(.failure(error))
            }
        }
    }

    private static func formattedName(from components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let formatter = PersonNameComponentsFormatter()
        let formatted = formatter.string(from: components).trimmingCharacters(in: .whitespacesAndNewlines)
        return formatted.isEmpty ? nil : formatted
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        presentationWindow ?? Self.keyWindow()
    }
}
#endif
