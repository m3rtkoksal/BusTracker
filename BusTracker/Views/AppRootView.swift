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
              let userID = authService.currentUserID else { return }

        do {
            if let profile = try await store.fetchUserProfile(userID: userID) {
                session.save(profile)
                await NotificationService.shared.requestPermissionAndRegister()

                let effectiveGroupID = profile.groupID ?? profile.primaryGroupID
                let memberID = profile.memberID

                if !effectiveGroupID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    await NotificationService.shared.saveTokenToProfile(
                        groupID: effectiveGroupID,
                        memberID: memberID
                    )
                }
            }
        } catch {
            // Profil alınamazsa giriş ekranına düşürülür.
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
                Text("2. Authentication → Phone etkin olmalı")
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
