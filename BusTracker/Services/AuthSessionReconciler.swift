import FirebaseAuth
import Foundation

/// Uygulama silinse bile Firebase Auth Keychain'de kalabilir; yerel profille eşleştirir.
enum AuthSessionReconciler {
    @MainActor
    static func reconcile(session: UserSession, authService: AuthService) async {
        await authService.waitUntilReady()

        let hasLocalProfile = session.profile != nil
        let hasFirebaseUser = authService.isSignedIn

        if hasFirebaseUser, !hasLocalProfile {
            print("⚠️ [Shuttle Live] Yerel profil yok ama Firebase oturumu var — Keychain kalıntısı, çıkış yapılıyor")
            try? authService.signOut()
            session.clearLocalProfile()
            return
        }

        if !hasFirebaseUser, hasLocalProfile {
            print("⚠️ [Shuttle Live] Yerel profil var ama Firebase oturumu yok — profil temizleniyor")
            session.clearLocalProfile()
        }
    }
}
