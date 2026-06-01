import SwiftUI

struct SettingsInviteShareRow: View {
    let serviceCode: String
    var onError: ((String) -> Void)?

    @State private var isSharing = false
    @State private var isLoadingLink = false
    @State private var inviteURL: URL?

    var body: some View {
        Button(action: shareInvite) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DAVET LİNKİ PAYLAŞ")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(NeonTheme.onSurfaceVariant)
                    Text(displayURL)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NeonTheme.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                }
                Spacer()
                if isSharing || isLoadingLink {
                    ProgressView()
                        .tint(NeonTheme.secondary)
                } else {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(NeonTheme.secondary)
                }
            }
            .padding(16)
            .background(NeonTheme.surfaceContainer)
            .overlay {
                Rectangle()
                    .strokeBorder(NeonTheme.outline.opacity(0.3), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(isSharing || isLoadingLink)
        .task(id: serviceCode) {
            await loadInviteLink()
        }
    }

    private var displayURL: String {
        inviteURL?.absoluteString
            ?? SmlerConfig.shortLinkURL(shortCode: serviceCode)?.absoluteString
            ?? "https://\(SmlerConfig.linkDomain)/\(SmlerConfig.normalizedCode(serviceCode))"
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
