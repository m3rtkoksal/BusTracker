import SwiftUI

@main
struct BusTrackerApp: App {
#if os(iOS) || os(visionOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
#endif

    init() {
        _ = FirebaseAppConfigurator.activated
    }

    @State private var session = UserSession.shared
    @State private var authService = AuthService.shared
    @State private var firebaseSession = FirebaseSession.shared
    @State private var store = ShuttleStore()
    @State private var locationTracker = LocationTracker()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(session)
                .environment(authService)
                .environment(firebaseSession)
                .environment(store)
                .environment(locationTracker)
        }
    }
}
