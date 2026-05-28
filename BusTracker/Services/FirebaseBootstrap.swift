import FirebaseCore
import FirebaseFirestore

enum FirebaseBootstrapError: LocalizedError {
    case missingConfiguration
    case authenticationFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            "GoogleService-Info.plist bulunamadı. Dosyanın BusTracker hedefinde Copy Bundle Resources içinde olduğundan emin olun."
        case .authenticationFailed(let message):
            "Firebase bağlantısı kurulamadı: \(message)"
        }
    }
}

enum FirebaseManager {
    private static var didConfigure = false

    static func configureIfNeeded() {
        guard !didConfigure else { return }
        guard FirebaseApp.app() == nil else {
            didConfigure = true
            return
        }

        if let filePath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let options = FirebaseOptions(contentsOfFile: filePath) {
            FirebaseApp.configure(options: options)
        } else {
            print("⚠️ [BusTracker] GoogleService-Info.plist bundle'da yok, varsayılan configure deneniyor")
            FirebaseApp.configure()
        }

        guard FirebaseApp.app() != nil else {
            print("❌ [BusTracker] FirebaseApp.configure sonrası app nil")
            return
        }

        var settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings()
        Firestore.firestore().settings = settings
        didConfigure = true
    }
}

private enum FirebaseLaunch {
    static let configure: Void = {
        FirebaseManager.configureIfNeeded()
    }()
}

let firebaseConfiguredAtModuleLoad = FirebaseLaunch.configure
