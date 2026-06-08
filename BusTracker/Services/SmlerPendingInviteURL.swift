import Foundation

/// AppDelegate → SwiftUI: soğuk açılışta universal link / custom scheme kaydı.
@MainActor
enum SmlerPendingInviteURL {
    private static var url: URL?

    static func capture(_ url: URL) {
        guard isInviteURL(url) else { return }
        self.url = url
        print("[Smler] Launch URL kaydedildi: \(url.absoluteString)")
    }

    static func consume() -> URL? {
        defer { url = nil }
        return url
    }

    static func isInviteURL(_ url: URL) -> Bool {
        if url.scheme?.lowercased() == "shuttlelive" { return true }
        return SmlerConfig.isSmlerLink(url)
    }
}
