import Foundation

/// Smler deeplink ayarları — dashboard: https://app.smler.io
enum SmlerConfig {
    /// Workspace domain (Smler → Domains).
    static let linkDomain = "shuttlelive.smler.io"

    static let resolveAPIBase = "https://smler.in/api/v1"
    /// Link oluşturma — `app.smler.io` panel; API `smler.in` üzerinde.
    static let createAPIBase = "https://smler.in/api/v1"

    /// Smler ara sayfası / paylaşım önizlemesi (Custom OG Tags).
    static let inviteOGTitle = "Shuttle Live — Servis daveti"
    static let inviteOGDescription =
        "Resmi Shuttle Live uygulaması. Servis kodunuzla güvenle katılın. App Store’dan indirin."
    /// Shuttle Live marka ikonu (Firebase Hosting — Smler OG / ara sayfa).
    static let inviteOGImageURL =
        "https://bustracker-717a3.web.app/shuttle-live-og.png"

    /// Uygulama içi hedef URL (Smler `url` alanı); çözümlenince servis kodu okunur.
    static func destinationURL(serviceCode: String) -> String {
        let code = normalizedCode(serviceCode)
        return "shuttlelive://passenger/join?code=\(code)"
    }

    static func shortLinkURL(shortCode: String) -> URL? {
        let code = normalizedCode(shortCode)
        guard code.count >= 4 else { return nil }
        return URL(string: "https://\(linkDomain)/\(code)")
    }

    static func normalizedCode(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    static func isSmlerLink(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == linkDomain || host.hasSuffix(".\(linkDomain)")
    }

    /// Info.plist → `SmlerAPIKey` (Smler dashboard API key, `x-code` header).
    static var apiKey: String? {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SmlerAPIKey") as? String else {
            return nil
        }
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
