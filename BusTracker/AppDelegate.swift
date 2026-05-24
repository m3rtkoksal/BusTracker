#if os(iOS) || os(visionOS)
import FirebaseAuth
import FirebaseMessaging
import UIKit

@objc(AppDelegate)
final class AppDelegate: NSObject, UIApplicationDelegate {
    @objc func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseAuthLaunch.start(in: application)
        application.registerForRemoteNotifications()
        return true
    }

    @objc func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        guard FirebaseAuthLaunch.isReady else { return }
        Auth.auth().setAPNSToken(deviceToken, type: .unknown)
        Messaging.messaging().apnsToken = deviceToken
    }

    @objc(application:didReceiveRemoteNotification:fetchCompletionHandler:)
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard FirebaseAuthLaunch.isReady else {
            completionHandler(.noData)
            return
        }
        if Auth.auth().canHandleNotification(userInfo) {
            completionHandler(.noData)
            return
        }
        completionHandler(.noData)
    }

    @objc(application:openURL:options:)
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
