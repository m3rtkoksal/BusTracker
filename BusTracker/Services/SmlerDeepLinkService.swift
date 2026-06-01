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

    private let deferredHandledKey = "smler_deferred_handled_v1"
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
            return .failure("Geçerli bir servis kodu yok.")
        }
        guard SmlerConfig.apiKey != nil else {
            log("HATA: SmlerAPIKey boş (Info.plist)")
            return .failure("Smler API anahtarı tanımlı değil. Xcode → Info.plist → SmlerAPIKey alanına dashboard’daki API key’i yapıştırın.")
        }
        log("API key yüklü (uzunluk=\(SmlerConfig.apiKey?.count ?? 0))")

        switch await createInviteDeepLink(serviceCode: code) {
        case .success(let url):
            log("OK shortURL=\(url.absoluteString)")
            let message = """
            Shuttle Live servis daveti

            Servis kodu: \(code)
            \(url.absoluteString)
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

    func serviceCodeFromDeferredInstall() async -> String? {
        guard !UserDefaults.standard.bool(forKey: deferredHandledKey) else { return nil }
        UserDefaults.standard.set(true, forKey: deferredHandledKey)

#if os(iOS) || os(visionOS)
        guard let pasted = UIPasteboard.general.string?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !pasted.isEmpty,
              let url = URL(string: pasted),
              SmlerConfig.isSmlerLink(url) else {
            return nil
        }
        return await resolveServiceCode(fromSmlerURL: url)
#else
        return nil
#endif
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
            return .failure("Smler API anahtarı eksik.")
        }
        guard let endpoint = URL(string: "\(SmlerConfig.createAPIBase)/short") else {
            return .failure("Smler API adresi geçersiz.")
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
                return .failure("Smler yanıt vermedi.")
            }
            let responseText = String(data: data, encoding: .utf8) ?? "<okunamadı>"
            log("response status=\(http.statusCode)")
            log("response body: \(responseText)")

            guard (200 ... 299).contains(http.statusCode) else {
                let detail = apiErrorMessage(from: data) ?? shortAPIErrorHint(status: http.statusCode)
                return .failure("Smler link oluşturulamadı (\(http.statusCode)): \(detail)")
            }
            if let url = parseShortURL(from: data) ?? SmlerConfig.shortLinkURL(shortCode: code) {
                cacheURL(url, for: code)
                return .success(url)
            }
            log("HATA: yanıtta short URL parse edilemedi")
            return .failure("Smler kısa link adresi alınamadı. Console’daki response body’ye bakın.")
        } catch {
            log("HATA network: \(error.localizedDescription)")
            return .failure("Bağlantı hatası: \(error.localizedDescription)")
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
        if status == 404 { return "API adresi bulunamadı." }
        return "Ayrıntı için Xcode console [Smler] satırlarına bakın."
    }

    private func resolveServiceCode(fromSmlerURL url: URL) async -> String? {
        let pathCode = shortCodeFromPath(url)
        if let resolved = await fetchResolvedDestination(shortCode: pathCode, dltHeader: nil),
           let code = serviceCodeFromDestination(resolved) {
            return code
        }
        if pathCode.count >= 4 {
            return pathCode
        }
        return nil
    }

    private func fetchResolvedDestination(shortCode: String, dltHeader: String?) async -> URL? {
        var components = URLComponents(string: "\(SmlerConfig.resolveAPIBase)/short")
        var query: [URLQueryItem] = [
            URLQueryItem(name: "short", value: shortCode),
            URLQueryItem(name: "domain", value: SmlerConfig.linkDomain)
        ]
        if let dltHeader, !dltHeader.isEmpty {
            query.append(URLQueryItem(name: "dltHeader", value: dltHeader))
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

    private func shortCodeFromPath(_ url: URL) -> String {
        let parts = url.path.split(separator: "/").map(String.init)
        return parts.last.map { SmlerConfig.normalizedCode($0) } ?? ""
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
