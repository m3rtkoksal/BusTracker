import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum SmlerShareOutcome {
    case success(message: String, shortURL: URL)
    case failure(String)
}

/// Smler kısa link + deferred deep link — https://app.smler.io/docs/deep-links/introduction
@MainActor
final class SmlerDeepLinkService {
    static let shared = SmlerDeepLinkService()

    private let deferredHandledKey = "smler_deferred_handled_v2"
    private let urlCachePrefix = "smler_cached_url_"

    private init() {}

    private func log(_ message: String) {
        print("[Smler] \(message)")
    }

    // MARK: - Paylaşım (Smler panelindeki Create link ile aynı mantık)

    /// Paylaş / Davet linki: önce Smler API ile deep link oluşturur, sonra paylaşım metni döner.
    func prepareShare(serviceCode: String) async -> SmlerShareOutcome {
        let code = SmlerConfig.normalizedCode(serviceCode)
        log("prepareShare başladı serviceCode=\(code)")
        guard code.count >= 4 else {
            log("HATA: servis kodu çok kısa")
            return .failure(L10n.invalidServiceCode)
        }
        guard SmlerConfig.apiKey != nil else {
            log("HATA: SmlerAPIKey boş (Info.plist)")
            return .failure(L10n.smlerAPIKeyMissingInfo)
        }
        log("API key yüklü (uzunluk=\(SmlerConfig.apiKey?.count ?? 0))")

        switch await createInviteDeepLink(serviceCode: code) {
        case .success(let url):
            log("OK shortURL=\(url.absoluteString)")
            let message = """
            \(L10n.smlerShareTitle)

            \(L10n.smlerShareBody(code, url.absoluteString))
            """
            return .success(message: message, shortURL: url)
        case .failure(let error):
            log("HATA prepareShare: \(error)")
            return .failure(error)
        }
    }

    func shareMessage(serviceCode: String) async -> String? {
        if case .success(let message, _) = await prepareShare(serviceCode: serviceCode) {
            return message
        }
        return nil
    }

    /// Smler kısa linkini oluşturur veya önbellekten döner (UI ön yükleme).
    func ensureInviteLink(serviceCode: String) async -> URL? {
        let code = SmlerConfig.normalizedCode(serviceCode)
        guard code.count >= 4, SmlerConfig.apiKey != nil else { return nil }
        if case .success(let url) = await createInviteDeepLink(serviceCode: code) {
            return url
        }
        return nil
    }

    // MARK: - Gelen link

    func serviceCode(from url: URL) async -> String? {
        guard SmlerConfig.isSmlerLink(url) else {
            return serviceCodeFromDestination(url)
        }
        return await resolveServiceCode(fromSmlerURL: url)
    }

    /// İlk kurulum sonrası Smler deferred link — pano + IP eşleşmesi (Smler dokümantasyonu).
    /// Kayıt ekranı görünürken çağrılmalı; iOS yapıştırma izni diyaloğu için kısa gecikmeli tekrar dener.
    func serviceCodeFromDeferredInstall() async -> String? {
        guard !UserDefaults.standard.bool(forKey: deferredHandledKey) else { return nil }

#if os(iOS) || os(visionOS)
        let retryDelaysNs: [UInt64] = [0, 800_000_000, 2_000_000_000, 4_000_000_000]
        for delay in retryDelaysNs {
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }
            if let url = await clipboardInviteURL() {
                log("Deferred pano eşleşmesi: \(url.absoluteString)")
                if let code = await resolveServiceCode(fromSmlerURL: url, triggerWebhook: true) {
                    markDeferredInstallHandled()
                    return code
                }
            }
        }

        log("Deferred pano boş — probabilistic deneniyor")
        if let code = await probabilisticServiceCode() {
            markDeferredInstallHandled()
            return code
        }

        markDeferredInstallHandled()
        return nil
#else
        markDeferredInstallHandled()
        return nil
#endif
    }

    private func markDeferredInstallHandled() {
        UserDefaults.standard.set(true, forKey: deferredHandledKey)
    }

    // MARK: - Smler Create link API

    private enum CreateLinkResult {
        case success(URL)
        case failure(String)
    }

    private func createInviteDeepLink(serviceCode: String) async -> CreateLinkResult {
        let code = SmlerConfig.normalizedCode(serviceCode)
        if let cached = cachedURL(for: code) {
            log("Önbellekten link: \(cached.absoluteString)")
            return .success(cached)
        }

        guard let apiKey = SmlerConfig.apiKey else {
            return .failure(L10n.smlerAPIKeyMissing)
        }
        guard let endpoint = URL(string: "\(SmlerConfig.createAPIBase)/short") else {
            return .failure(L10n.smlerAPIInvalid)
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-code")
        request.timeoutInterval = 25

        // Smler API zorunlu alan: maxLength. Deferred + custom domain.
        let body: [String: Any] = [
            "url": SmlerConfig.destinationURL(serviceCode: code),
            "shortCode": code,
            "domain": SmlerConfig.linkDomain,
            "maxLength": max(code.count, 6),
            "forever": true,
            "isDeferredLink": true,
            "ogTitle": SmlerConfig.inviteOGTitle,
            "ogDescription": SmlerConfig.inviteOGDescription,
            "ogImage": SmlerConfig.inviteOGImageURL
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        if let bodyData = request.httpBody, let bodyText = String(data: bodyData, encoding: .utf8) {
            log("POST \(endpoint.absoluteString)")
            log("request body: \(bodyText)")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                log("HATA: HTTPURLResponse yok")
                return .failure(L10n.smlerNoResponse)
            }
            let responseText = String(data: data, encoding: .utf8) ?? "<okunamadı>"
            log("response status=\(http.statusCode)")
            log("response body: \(responseText)")

            guard (200 ... 299).contains(http.statusCode) else {
                let detail = apiErrorMessage(from: data) ?? shortAPIErrorHint(status: http.statusCode)
                if let existing = existingShortLinkURL(
                    code: code,
                    status: http.statusCode,
                    responseBody: responseText
                ) {
                    log("Mevcut kısa link kullanılıyor: \(existing.absoluteString)")
                    cacheURL(existing, for: code)
                    return .success(existing)
                }
                return .failure(L10n.smlerLinkFailed(http.statusCode, detail))
            }
            if let url = parseShortURL(from: data) ?? SmlerConfig.shortLinkURL(shortCode: code) {
                cacheURL(url, for: code)
                return .success(url)
            }
            log("HATA: yanıtta short URL parse edilemedi")
            return .failure(L10n.smlerShortLinkMissing)
        } catch {
            log("HATA network: \(error.localizedDescription)")
            return .failure(L10n.connectionErrorDetail(error.localizedDescription))
        }
    }

    private func apiErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let message = json["message"] as? String { return message }
        if let error = json["error"] as? String { return error }
        if let errors = json["error"] as? [[String: Any]],
           let first = errors.first,
           let msg = first["message"] as? String {
            return msg
        }
        return nil
    }

    private func shortAPIErrorHint(status: Int) -> String {
        if status == 404 { return L10n.apiURLNotFound }
        return L10n.checkXcodeConsole
    }

    /// Smler'de shortCode zaten kayıtlıysa (400) oluşturma yerine bilinen kısa URL kullanılır.
    private func existingShortLinkURL(code: String, status: Int, responseBody: String) -> URL? {
        guard status == 400 || status == 409 else { return nil }
        let body = responseBody.lowercased()
        guard body.contains("already exists") || body.contains("unable to create short url") else {
            return nil
        }
        return SmlerConfig.shortLinkURL(shortCode: code)
    }

    private func resolveServiceCode(fromSmlerURL url: URL, triggerWebhook: Bool = false) async -> String? {
        if url.scheme?.lowercased() == "shuttlelive",
           let code = serviceCodeFromDestination(url) {
            return code
        }

        let pathParams = extractPathParams(from: url)
        guard !pathParams.shortCode.isEmpty else { return nil }

        if let resolved = await fetchResolvedDestination(
            shortCode: pathParams.shortCode,
            dltHeader: pathParams.dltHeader,
            triggerWebhook: triggerWebhook
        ),
           let code = serviceCodeFromDestination(resolved) {
            return code
        }
        if pathParams.shortCode.count >= 4 {
            return pathParams.shortCode
        }
        return nil
    }

#if os(iOS) || os(visionOS)
    private func clipboardInviteURL() async -> URL? {
        guard let clipboard = await readClipboardText()?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !clipboard.isEmpty else {
            return nil
        }

        if let url = parseURLLikeString(clipboard),
           url.scheme?.lowercased() == "shuttlelive" {
            return url
        }

        let patterns = [
            "https://\(SmlerConfig.linkDomain)",
            "http://\(SmlerConfig.linkDomain)",
            SmlerConfig.linkDomain
        ]
        for pattern in patterns where matchesDeepLinkPattern(clipboard: clipboard, pattern: pattern) {
            return parseURLLikeString(clipboard)
        }
        return nil
    }

    private func readClipboardText() async -> String? {
        if #available(iOS 16.0, *) {
            return await withCheckedContinuation { continuation in
                UIPasteboard.general.detectPatterns(for: [.probableWebURL]) { result in
                    switch result {
                    case .success:
                        continuation.resume(returning: UIPasteboard.general.string)
                    case .failure:
                        continuation.resume(returning: UIPasteboard.general.string)
                    }
                }
            }
        }
        return UIPasteboard.general.string
    }

    private func probabilisticServiceCode() async -> String? {
        guard let endpoint = URL(string: "https://smler.in/api/v2/track/probablistic") else {
            return nil
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "device": probabilisticDeviceName(),
            "os": "iOS \(UIDevice.current.systemVersion)",
            "domain": SmlerConfig.linkDomain
        ])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  json["matched"] as? Bool == true,
                  let score = json["score"] as? Double, score > 0.65 else {
                return nil
            }

            if let shortUrl = json["shortUrl"] as? [String: Any],
               let original = shortUrl["originalUrl"] as? String,
               let destination = URL(string: original),
               let code = serviceCodeFromDestination(destination) {
                log("Probabilistic eşleşme score=\(score) code=\(code)")
                return code
            }

            if let pathParams = json["pathParams"] as? [String: Any],
               let shortCode = pathParams["shortCode"] as? String {
                let normalized = SmlerConfig.normalizedCode(shortCode)
                if normalized.count >= 4 {
                    log("Probabilistic pathParams shortCode=\(normalized)")
                    return normalized
                }
            }
        } catch {
            log("Probabilistic HATA: \(error.localizedDescription)")
        }
        return nil
    }

    private func probabilisticDeviceName() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }

    private func matchesDeepLinkPattern(clipboard: String, pattern: String) -> Bool {
        let trimmedPattern = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPattern.isEmpty else { return false }

        let normalizedClipboard = normalizeURLLikeString(clipboard)
        let normalizedPattern = normalizeURLLikeString(trimmedPattern)
        if normalizedClipboard == normalizedPattern || normalizedClipboard.hasPrefix(normalizedPattern) {
            return true
        }

        guard let clipboardURI = parseURLLikeString(clipboard),
              let patternURI = parseURLLikeString(trimmedPattern) else {
            return false
        }

        func stripWWW(_ host: String) -> String {
            host.lowercased().hasPrefix("www.") ? String(host.dropFirst(4)) : host.lowercased()
        }

        let clipboardHost = stripWWW(clipboardURI.host ?? "")
        let patternHost = stripWWW(patternURI.host ?? "")
        guard !clipboardHost.isEmpty, !patternHost.isEmpty else { return false }

        let hostMatches = clipboardHost == patternHost || clipboardHost.hasSuffix(".\(patternHost)")
        guard hostMatches else { return false }

        let patternPath = patternURI.path
        if patternPath.isEmpty || patternPath == "/" { return true }
        let clipboardPath = clipboardURI.path.isEmpty ? "/" : clipboardURI.path
        return clipboardPath.hasPrefix(patternPath)
    }

    private func normalizeURLLikeString(_ value: String) -> String {
        var normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.lowercased().hasPrefix("https://") {
            normalized = String(normalized.dropFirst("https://".count))
        } else if normalized.lowercased().hasPrefix("http://") {
            normalized = String(normalized.dropFirst("http://".count))
        }
        return normalized
    }

    private func parseURLLikeString(_ value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), url.host != nil {
            return url
        }
        return URL(string: "https://\(trimmed)")
    }
#endif

    private struct SmlerPathParams {
        let shortCode: String
        let dltHeader: String?
    }

    private func extractPathParams(from url: URL) -> SmlerPathParams {
        let segments = url.path.split(separator: "/").map(String.init).filter { !$0.isEmpty }
        if segments.count >= 2 {
            return SmlerPathParams(
                shortCode: SmlerConfig.normalizedCode(segments[1]),
                dltHeader: segments[0]
            )
        }
        if let first = segments.first {
            return SmlerPathParams(shortCode: SmlerConfig.normalizedCode(first), dltHeader: nil)
        }
        return SmlerPathParams(shortCode: "", dltHeader: nil)
    }

    private func fetchResolvedDestination(
        shortCode: String,
        dltHeader: String?,
        triggerWebhook: Bool = false
    ) async -> URL? {
        var components = URLComponents(string: "\(SmlerConfig.resolveAPIBase)/short")
        var query: [URLQueryItem] = [
            URLQueryItem(name: "short", value: shortCode),
            URLQueryItem(name: "domain", value: SmlerConfig.linkDomain)
        ]
        if let dltHeader, !dltHeader.isEmpty {
            query.append(URLQueryItem(name: "dltHeader", value: dltHeader))
        }
        if triggerWebhook {
            query.append(URLQueryItem(name: "triggerWebhook", value: "true"))
        }
        components?.queryItems = query
        guard let url = components?.url else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(for: URLRequest(url: url))
            return parseDestinationURL(from: data)
        } catch {
            return nil
        }
    }

    private func serviceCodeFromDestination(_ url: URL) -> String? {
        if let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
           let code = items.first(where: { $0.name.lowercased() == "code" })?.value {
            let normalized = SmlerConfig.normalizedCode(code)
            return normalized.count >= 4 ? normalized : nil
        }
        let parts = url.path.split(separator: "/").map(String.init)
        if let joinIndex = parts.firstIndex(where: { $0.lowercased() == "join" }),
           parts.indices.contains(joinIndex + 1) {
            let normalized = SmlerConfig.normalizedCode(parts[joinIndex + 1])
            return normalized.count >= 4 ? normalized : nil
        }
        return nil
    }

    private func parseShortURL(from data: Data) -> URL? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        let link = json["link"] as? [String: Any]
        let dataObj = json["data"] as? [String: Any]
        let candidates: [String?] = [
            json["secureShortUrl"] as? String,
            json["shortUrl"] as? String,
            json["shortURL"] as? String,
            json["shortLink"] as? String,
            json["short_url"] as? String,
            link?["shortUrl"] as? String,
            link?["shortURL"] as? String,
            link?["url"] as? String,
            dataObj?["shortUrl"] as? String,
            dataObj?["url"] as? String
        ]
        for candidate in candidates {
            if let s = candidate?.trimmingCharacters(in: .whitespacesAndNewlines),
               !s.isEmpty,
               let url = URL(string: s),
               SmlerConfig.isSmlerLink(url) || s.contains(SmlerConfig.linkDomain) {
                return url
            }
        }
        return nil
    }

    private func parseDestinationURL(from data: Data) -> URL? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        let candidates = [
            json["originalUrl"] as? String,
            json["originalURL"] as? String,
            (json["link"] as? [String: Any])?["url"] as? String,
            (json["data"] as? [String: Any])?["url"] as? String,
            json["url"] as? String
        ]
        for candidate in candidates {
            if let s = candidate, let url = URL(string: s) { return url }
        }
        return nil
    }

    private func cachedURL(for code: String) -> URL? {
        guard let s = UserDefaults.standard.string(forKey: urlCachePrefix + code) else { return nil }
        return URL(string: s)
    }

    private func cacheURL(_ url: URL, for code: String) {
        UserDefaults.standard.set(url.absoluteString, forKey: urlCachePrefix + code)
    }
}
