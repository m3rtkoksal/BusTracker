import SwiftUI

struct FirebaseGateView<Content: View>: View {
    @Environment(FirebaseSession.self) private var firebaseSession
    @ViewBuilder let content: () -> Content

    var body: some View {
        Group {
            if firebaseSession.isReady {
                content()
            } else if let error = firebaseSession.error {
                FirebaseErrorView(error: error) {
                    Task { await firebaseSession.bootstrap() }
                }
            } else {
                FirebaseLoadingView(message: "Firebase'e bağlanılıyor...")
            }
        }
        .task {
            await firebaseSession.bootstrap()
        }
    }
}

private struct FirebaseLoadingView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

private struct FirebaseErrorView: View {
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
    }
}

#Preview {
    FirebaseGateView {
        Text("Uygulama")
    }
    .environment(FirebaseSession.shared)
}
