#if os(iOS) || os(visionOS)
import FirebaseAuth
import FirebaseCore
import FirebaseMessaging
import UIKit

/// FirebaseAppDelegateProxyEnabled = true — Auth/Messaging APNs, `didRegister` swizzler + interceptor ile alınır.
@objc(AppDelegate)
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseManager.configureIfNeeded()

        if FirebaseApp.app() == nil {
            print("❌ [BusTracker] FirebaseApp.configure() başarısız")
        } else {
            print("✅ [BusTracker] Firebase Core yapılandırıldı")
        }

        FirebaseAuthLaunch.start(in: application) {
            // registerForRemoteNotifications, Auth hazır olduktan sonra FirebaseAuthLaunch içinde çağrılır
        }

        if let userInfo = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            Task { @MainActor in
                PushNotificationRouter.handle(userInfo: userInfo)
            }
        }

        return true
    }

    /// Yalnızca FCM / yerel izleme — Auth token'ı swizzler interceptor'ına bırakılır (`setAPNSToken` çağrılmaz).
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        FirebaseAuthLaunch.storeDeviceToken(deviceToken)
        NotificationService.shared.setAPNSToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("⚠️ [BusTracker] APNs kaydı başarısız: \(error.localizedDescription)")
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        guard FirebaseAuthLaunch.isReady else { return false }
        return Auth.auth().canHandle(url)
    }
}
#endif
