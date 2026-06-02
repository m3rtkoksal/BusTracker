import FirebaseAuth
import Foundation

enum AuthErrorMessage {
    private static var appDisplayName: String {
        if let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           !name.isEmpty {
            return name
        }
        return "Shuttle Live"
    }

    static func log(_ error: Error, context: String) {
        let nsError = error as NSError
        print("❌ [BusTracker Auth:\(context)] domain=\(nsError.domain) code=\(nsError.code)")
        print("   description: \(nsError.localizedDescription)")
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            print("   underlying: \(underlying.domain) \(underlying.code) — \(underlying.localizedDescription)")
        }
        if !nsError.userInfo.isEmpty {
            print("   userInfo: \(nsError.userInfo)")
        }
    }

    static func message(for error: Error) -> String {
        if let appleError = error as? AppleSignInError {
            return appleError.localizedDescription
        }

        let nsError = error as NSError

        if nsError.domain == AuthErrorDomain,
           let code = AuthErrorCode(rawValue: nsError.code) {
            switch code {
            case .networkError:
                return L10n.networkError
            case .tooManyRequests:
                return L10n.tooManyRequests
            case .userDisabled:
                return L10n.accountDisabled
            case .operationNotAllowed:
                return L10n.appleSignInNotEnabled
            case .invalidCredential, .userMismatch:
                return L10n.appleCredentialInvalid
            default:
                break
            }
        }

        if textContainsAuthCancellation(nsError) {
            return L10n.appleSignInCancelled
        }

        return nsError.localizedDescription
    }

    private static func textContainsAuthCancellation(_ error: NSError) -> Bool {
        let text = error.localizedDescription.lowercased()
        return text.contains("cancel") || text.contains("iptal")
    }
}
