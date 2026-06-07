import SwiftUI

struct SettingsInviteShareRow: View {
    let serviceCode: String
    var onError: ((String) -> Void)?

    @State private var isSharing = false
    @State private var isLoadingLink = false
    @State private var inviteURL: URL?

    var body: some View {
        HStack {
            Text(L10n.inviteLinkTitle)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(NeonTheme.onSurfaceVariant)

            Spacer()

            Button(action: shareInvite) {
                if isSharing || isLoadingLink {
                    ProgressView()
                        .tint(NeonTheme.secondary)
                        .frame(width: 72, height: 32)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption)
                        Text(L10n.share.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(1.5)
                    }
                    .foregroundStyle(NeonTheme.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(NeonTheme.secondary.opacity(0.12))
                    .overlay {
                        Rectangle()
                            .strokeBorder(NeonTheme.secondary.opacity(0.4), lineWidth: 1)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isSharing || isLoadingLink)
        }
        .padding(16)
        .background(NeonTheme.surfaceContainer)
        .overlay {
            Rectangle()
                .strokeBorder(NeonTheme.outline.opacity(0.3), lineWidth: 1)
        }
        .task(id: serviceCode) {
            await loadInviteLink()
        }
    }

    private func loadInviteLink() async {
#if os(iOS) || os(visionOS)
        guard !isLoadingLink else { return }
        isLoadingLink = true
        defer { isLoadingLink = false }
        if let url = await SmlerDeepLinkService.shared.ensureInviteLink(serviceCode: serviceCode) {
            inviteURL = url
        }
#endif
    }

    private func shareInvite() {
#if os(iOS) || os(visionOS)
        guard !isSharing else { return }
        isSharing = true
        Task {
            defer { isSharing = false }
            switch await SmlerDeepLinkService.shared.prepareShare(serviceCode: serviceCode) {
            case .success(let message, let url):
                inviteURL = url
                SharePresenter.present(items: [url, message])
            case .failure(let error):
                onError?(error)
            }
        }
#endif
    }
}
