import Foundation
import SwiftUI

@MainActor
@Observable
final class SmlerInviteCoordinator {
    var pendingRegistrationCode: String?
    var pendingAddServiceCode: String?
    var alreadyMemberMessage: String?
    private(set) var inviteRevision = 0

    private var deferredInviteCode: String?
    private var lastHandledCode: String?
    private let persistedRegistrationCodeKey = "smler_pending_registration_code_v1"

    func ingest(serviceCode: String) {
        let normalized = SmlerConfig.normalizedCode(serviceCode)
        guard normalized.count >= 4 else { return }
        deferredInviteCode = normalized
        pendingRegistrationCode = normalized
        UserDefaults.standard.set(normalized, forKey: persistedRegistrationCodeKey)
        inviteRevision += 1
    }

    func processIncomingURL(_ url: URL) async {
        guard let code = await SmlerDeepLinkService.shared.serviceCode(from: url) else { return }
        ingest(serviceCode: code)
    }

    /// Uygulama yeniden açılırsa veya kayıt ekranı geç yüklenirse davet kodunu geri yükle.
    func restorePersistedRegistrationInviteIfNeeded() {
        guard pendingRegistrationCode == nil, deferredInviteCode == nil else { return }
        guard let stored = UserDefaults.standard.string(forKey: persistedRegistrationCodeKey) else { return }
        ingest(serviceCode: stored)
    }

    /// Kayıt akışında davet kodu bekleniyor (rol seçimini atlamak için).
    var hasPassengerRegistrationInvite: Bool {
        (deferredInviteCode?.count ?? 0) >= 4 || (pendingRegistrationCode?.count ?? 0) >= 4
    }

    func preparePassengerRegistrationFromDeferred() {
        if let code = deferredInviteCode {
            pendingRegistrationCode = code
        }
    }

    func consumeRegistrationInvite() {
        pendingRegistrationCode = nil
        deferredInviteCode = nil
        UserDefaults.standard.removeObject(forKey: persistedRegistrationCodeKey)
    }

    func clearAddServicePending() {
        pendingAddServiceCode = nil
    }

    func dismissAlreadyMemberMessage() {
        alreadyMemberMessage = nil
    }

    func handleIfReady(profile: UserProfile?, isSignedIn: Bool, store: ShuttleStore) async {
        guard let code = deferredInviteCode else { return }

        if let profile, profile.role == .driver {
            discardInvite(keepingLastHandled: code)
            return
        }

        guard isSignedIn, let profile else { return }

        if await isAlreadyMember(code: code, profile: profile, store: store) {
            alreadyMemberMessage = L10n.alreadyMemberOfShuttle
            discardInvite(keepingLastHandled: code)
            return
        }

        pendingRegistrationCode = nil
        pendingAddServiceCode = code
        deferredInviteCode = nil
        lastHandledCode = code
    }

    private func discardInvite(keepingLastHandled code: String) {
        deferredInviteCode = nil
        pendingRegistrationCode = nil
        pendingAddServiceCode = nil
        lastHandledCode = code
    }

    private func isAlreadyMember(code: String, profile: UserProfile, store: ShuttleStore) async -> Bool {
        guard let groupID = try? await store.resolveGroupID(forCode: code) else { return false }
        var ids = profile.groupIDs
        if ids.isEmpty, let legacy = profile.groupID, !legacy.isEmpty {
            ids = [legacy]
        }
        return ids.contains(groupID)
    }
}
