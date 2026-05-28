#if os(iOS) || os(visionOS)
import FirebaseAuth
import FirebaseCore
import FirebaseMessaging
import UIKit

enum FirebaseAuthLaunch {
    private(set) static var isReady = false
    private(set) static var hasDeviceToken = false
    private static var didStart = false
    private static var deviceToken: Data?

    static func start(in application: UIApplication, onReady: @escaping () -> Void) {
        guard !didStart else {
            if isReady { onReady() }
            return
        }
        didStart = true

        guard FirebaseApp.app() != nil else {
            print("❌ [BusTracker] FirebaseApp nil")
            return
        }

        Task { @MainActor in
            _ = application.delegate
            _ = Auth.auth()
            await waitForAuthPhoneAuthStack()
            isReady = true
            AuthService.shared.ensureConfigured()
            print("✅ [BusTracker] Firebase Auth hazır (Phone Auth / APNs proxy hazır)")
            onReady()
            await refreshRemoteNotificationRegistration(application)
        }
    }

    /// APNs token'ı Auth'a **elle** vermeyin — `setAPNSToken` tokenManager hazır değilse crash verir.
    /// `FirebaseAppDelegateProxyEnabled` + Auth interceptor token'ı alır.
    static func storeDeviceToken(_ token: Data) {
        deviceToken = token
        hasDeviceToken = true
        Messaging.messaging().apnsToken = token
        print("✅ [BusTracker] APNs token alındı (Messaging)")
    }

    static func syncAPNSTokenToAuth() {
        // Bilinçli no-op: token Auth'a yalnızca GoogleUtilities swizzler ile gider.
    }

    static func waitForPhoneAuthSetup() async {
        await waitUntilReady()
        if hasDeviceToken || Messaging.messaging().apnsToken != nil {
            hasDeviceToken = true
            return
        }
        for _ in 0..<40 {
            if Messaging.messaging().apnsToken != nil {
                hasDeviceToken = true
                return
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
        print("⚠️ [BusTracker] APNs token gelmedi — Phone Auth reCAPTCHA kullanabilir")
    }

    static func waitUntilReady() async {
        if isReady { return }
        for _ in 0..<100 {
            if isReady { return }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    @MainActor
    private static func waitForAuthPhoneAuthStack() async {
        _ = Auth.auth()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var finished = false
            let finish: () -> Void = {
                guard !finished else { return }
                finished = true
                continuation.resume()
            }

            var observer: NSObjectProtocol?
            observer = NotificationCenter.default.addObserver(
                forName: Auth.authStateDidChangeNotification,
                object: nil,
                queue: .main
            ) { _ in
                if let observer {
                    NotificationCenter.default.removeObserver(observer)
                }
                finish()
            }

            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                if let observer {
                    NotificationCenter.default.removeObserver(observer)
                }
                finish()
            }
        }

        try? await Task.sleep(for: .milliseconds(400))
    }

    /// Token, Auth interceptor kaydından önce geldiyse yeniden kayıt sessiz push'u Auth'a iletir.
    @MainActor
    private static func refreshRemoteNotificationRegistration(_ application: UIApplication) async {
        application.registerForRemoteNotifications()
        try? await Task.sleep(for: .milliseconds(600))
        if !hasDeviceToken {
            application.registerForRemoteNotifications()
        }
    }
}
#endif
