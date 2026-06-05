import SwiftUI

@main
struct BusTrackerApp: App {
#if os(iOS) || os(visionOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
#endif

    init() {
        _ = FirebaseAppConfigurator.activated
        LanguageManager.shared.applyPreferredLocalization()
    }

    @State private var session = UserSession.shared
    @State private var authService = AuthService.shared
    @State private var firebaseSession = FirebaseSession.shared
    @State private var store = ShuttleStore()
    @State private var locationTracker = LocationTracker()
    @State private var smlerInviteCoordinator = SmlerInviteCoordinator()
    @State private var languageManager = LanguageManager.shared

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(session)
                .environment(authService)
                .environment(firebaseSession)
                .environment(store)
                .environment(locationTracker)
                .environment(smlerInviteCoordinator)
                .environment(languageManager)
                .environment(\.locale, languageManager.locale)
                .id(languageManager.language)
                .onOpenURL { url in
                    Task { await handleSmlerURL(url) }
                }
#if os(iOS) || os(visionOS)
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    guard let url = activity.webpageURL else { return }
                    Task { await handleSmlerURL(url) }
                }
#endif
        }
    }

    private func handleSmlerURL(_ url: URL) async {
        guard let code = await SmlerDeepLinkService.shared.serviceCode(from: url) else { return }
        smlerInviteCoordinator.ingest(serviceCode: code)
    }
}
