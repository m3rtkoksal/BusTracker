import SwiftUI

/// LaunchScreen → Maps Lottie → uygulama (tek kesintisiz yükleme ekranı).
struct AppRootView: View {
    @Environment(FirebaseSession.self) private var firebaseSession
    @Environment(UserSession.self) private var session
    @Environment(AuthService.self) private var authService
    @Environment(ShuttleStore.self) private var store
    @Environment(SmlerInviteCoordinator.self) private var smlerInviteCoordinator

    @State private var isBootstrapped = false

    var body: some View {
        Group {
            if isBootstrapped, firebaseSession.isReady {
                ContentView()
            } else if let error = firebaseSession.error {
                FirebaseBootstrapErrorView(error: error) {
                    Task { await retryBootstrap() }
                }
            } else {
                AppLaunchView()
            }
        }
        .background(NeonTheme.background)
        .preferredColorScheme(.dark)
        .task {
            await runBootstrapIfNeeded()
        }
    }

    private func runBootstrapIfNeeded() async {
        guard !isBootstrapped else { return }

        await firebaseSession.bootstrap()
        guard firebaseSession.isReady else { return }

        await AuthSessionReconciler.reconcile(session: session, authService: authService)
        isBootstrapped = true
        await loadSignedInUserIfNeeded()
        await processSmlerDeferredInviteIfNeeded()
    }

    private func processSmlerDeferredInviteIfNeeded() async {
        guard let code = await SmlerDeepLinkService.shared.serviceCodeFromDeferredInstall() else {
            return
        }
        smlerInviteCoordinator.ingest(serviceCode: code)
    }

    private func retryBootstrap() async {
        isBootstrapped = false
        await runBootstrapIfNeeded()
    }

    private func loadSignedInUserIfNeeded() async {
        await authService.waitUntilReady()

        guard authService.isSignedIn,
              !authService.isCompletingRegistration,
              let userID = authService.currentUserID else {
            if session.profile != nil {
                session.clearLocalProfile()
            }
            return
        }

        do {
            if let profile = try await fetchProfileWithTimeout(userID: userID, store: store) {
                session.save(profile)
            } else {
                print("⚠️ [Shuttle Live] Firestore'da profil yok — oturum kapatılıyor")
                try? authService.signOut()
                session.clearLocalProfile()
            }
        } catch {
            print("⚠️ [Shuttle Live] Firestore profili yüklenemedi — oturum kapatılıyor: \(error.localizedDescription)")
            try? authService.signOut()
            session.clearLocalProfile()
        }
    }

    private func fetchProfileWithTimeout(
        userID: String,
        store: ShuttleStore,
        seconds: UInt64 = 12
    ) async throws -> UserProfile? {
        try await withThrowingTaskGroup(of: UserProfile?.self) { group in
            group.addTask {
                try await store.fetchUserProfile(userID: userID)
            }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw URLError(.timedOut)
            }

            defer { group.cancelAll() }
            guard let profile = try await group.next() else { return nil }
            return profile
        }
    }
}

private struct FirebaseBootstrapErrorView: View {
    let error: FirebaseBootstrapError
    let onRetry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(L10n.connectionError, systemImage: "wifi.exclamationmark")
        } description: {
            Text(error.localizedDescription)
        } actions: {
            Button(L10n.tryAgain, action: onRetry)
                .buttonStyle(.borderedProminent)

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.firebaseChecklistTitle)
                    .font(.caption.weight(.semibold))
                Text(L10n.firebaseCheck1)
                Text(L10n.firebaseCheck2)
                Text(L10n.firebaseCheck3)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .padding(.top, 8)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NeonTheme.background)
    }
}
