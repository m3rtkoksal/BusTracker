import SwiftUI

@main
struct BusTrackerApp: App {
#if os(iOS) || os(visionOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
#endif

    @State private var session = UserSession.shared
    @State private var authService = AuthService.shared
    @State private var firebaseSession = FirebaseSession.shared
    @State private var store = ShuttleStore()
    @State private var locationTracker = LocationTracker()

    var body: some Scene {
        WindowGroup {
            FirebaseGateView {
                ContentView()
            }
            .environment(session)
            .environment(authService)
            .environment(firebaseSession)
            .environment(store)
            .environment(locationTracker)
        }
    }
}
