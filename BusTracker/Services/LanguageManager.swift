import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case turkish = "tr"
    case english = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .turkish: "Türkçe"
        case .english: "English"
        }
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }
}

@MainActor
@Observable
final class LanguageManager {
    static let shared = LanguageManager()

    private static let storageKey = "app.selectedLanguage"

    var language: AppLanguage {
        didSet {
            guard language != oldValue else { return }
            UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey)
        }
    }

    var locale: Locale { language.locale }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: Self.storageKey),
           let savedLanguage = AppLanguage(rawValue: saved) {
            language = savedLanguage
        } else {
            let preferred = Locale.preferredLanguages.first ?? "en"
            language = preferred.hasPrefix("tr") ? .turkish : .english
        }
    }

    func t(_ turkish: String, _ english: String) -> String {
        language == .turkish ? turkish : english
    }

    func setLanguage(_ language: AppLanguage) {
        self.language = language
    }
}
