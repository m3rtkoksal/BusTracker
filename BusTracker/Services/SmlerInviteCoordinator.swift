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

    func ingest(serviceCode: String) {
        let normalized = SmlerConfig.normalizedCode(serviceCode)
        guard normalized.count >= 4 else { return }
        deferredInviteCode = normalized
        inviteRevision += 1
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
            alreadyMemberMessage = "Bu servise zaten kayıtlısınız."
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
