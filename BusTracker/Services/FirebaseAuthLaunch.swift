#if os(iOS) || os(visionOS)
import FirebaseAuth
import FirebaseCore
import UIKit

/// Firebase Auth iOS bileşenleri yalnızca `UIApplication` hazırken kurulur.
/// `canHandleNotification` notificationManager nil iken crash verir — asla probe çağırma.
enum FirebaseAuthLaunch {
    private(set) static var isReady = false
    private static var didStart = false

    static func start(in application: UIApplication) {
        guard !didStart else { return }
        didStart = true

        Task { @MainActor in
            FirebaseManager.configureIfNeeded()
            guard FirebaseApp.app() != nil else { return }

            _ = application.delegate
            try? await Task.sleep(for: .milliseconds(300))

            _ = Auth.auth()
            try? await Task.sleep(for: .milliseconds(800))

            isReady = true
            AuthService.shared.ensureConfigured()
            NotificationService.shared.configure()
        }
    }

    static func waitUntilReady() async {
        if isReady { return }
        for _ in 0..<60 {
            if isReady { return }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }
}
#endif
