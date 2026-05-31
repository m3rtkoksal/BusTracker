import SwiftUI

/// LaunchScreen → Maps Lottie → uygulama (tek kesintisiz yükleme ekranı).
struct AppRootView: View {
    @Environment(FirebaseSession.self) private var firebaseSession
    @Environment(UserSession.self) private var session
    @Environment(AuthService.self) private var authService
    @Environment(ShuttleStore.self) private var store

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
        await loadSignedInUserIfNeeded()
        isBootstrapped = true
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
            if let profile = try await store.fetchUserProfile(userID: userID) {
                session.save(profile)
            } else {
                print("⚠️ [Shuttle Live] Firestore'da profil yok — oturum kapatılıyor")
                try? authService.signOut()
                session.clearLocalProfile()
            }
        } catch {
            print("⚠️ [Shuttle Live] Firestore profili yüklenemedi — oturum kapatılıyor")
            try? authService.signOut()
            session.clearLocalProfile()
        }
    }
}

private struct FirebaseBootstrapErrorView: View {
    let error: FirebaseBootstrapError
    let onRetry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Bağlantı Hatası", systemImage: "wifi.exclamationmark")
        } description: {
            Text(error.localizedDescription)
        } actions: {
            Button("Tekrar Dene", action: onRetry)
                .buttonStyle(.borderedProminent)

            VStack(alignment: .leading, spacing: 8) {
                Text("Firebase Console kontrol listesi:")
                    .font(.caption.weight(.semibold))
                Text("1. Firestore Database oluşturulmuş olmalı")
                Text("2. Authentication → Apple etkin olmalı")
                Text("3. Push Notifications (APNs) yapılandırılmalı")
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
