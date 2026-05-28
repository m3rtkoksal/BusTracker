import FirebaseCore

/// Diğer Firebase modüllerinden önce çalışır (dosya adı erken yükleme için).
enum FirebaseAppConfigurator {
    static let activated: Void = {
        if FirebaseApp.app() == nil {
            if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
               let options = FirebaseOptions(contentsOfFile: path) {
                FirebaseApp.configure(options: options)
            } else {
                FirebaseApp.configure()
            }
            print("✅ [BusTracker] Firebase Early configure (Swift)")
        }
    }()
}

private let activateFirebaseEarly = FirebaseAppConfigurator.activated
