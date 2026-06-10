import SwiftUI

struct DriverSubscriptionView: View {
    @Environment(UserSession.self) private var session
    @State private var viewModel = DriverSubscriptionViewModel()
    @State private var copyToast: String?

    private var groupID: String {
        session.profile?.primaryGroupID ?? ""
    }

    private var serviceCode: String {
        session.profile?.groupCode ?? ""
    }

    var body: some View {
        ZStack {
            NeonTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection

                    VStack(spacing: 12) {
                        SettingsInfoRow(
                            title: L10n.subscriptionStartDate,
                            value: viewModel.startDateText
                        )
                        SettingsInfoRow(
                            title: L10n.subscriptionEndDate,
                            value: viewModel.endDateText
                        )
                    }

                    renewalLinkSection

                    Text(L10n.subscriptionPaymentHint)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(NeonTheme.outline)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .padding(24)
            }
        }
        .navigationTitle(L10n.subscription)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(NeonTheme.background.opacity(0.97), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task(id: groupID) {
            await viewModel.load(groupID: groupID)
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .tint(NeonTheme.secondary)
            }
        }
        .overlay(alignment: .top) {
            if let copyToast {
                Text(copyToast)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(NeonTheme.onSurface)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(NeonTheme.surfaceContainer)
                    .overlay {
                        Rectangle()
                            .strokeBorder(NeonTheme.secondary.opacity(0.4), lineWidth: 1)
                    }
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: copyToast)
        .task(id: copyToast) {
            guard copyToast != nil else { return }
            try? await Task.sleep(for: .seconds(2))
            copyToast = nil
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.subscriptionSectionTitle.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundStyle(NeonTheme.primary)

            Text(
                viewModel.subscription.isActive
                    ? L10n.subscriptionActiveDescription
                    : L10n.subscriptionInactiveDescription
            )
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(NeonTheme.onSurfaceVariant)
            .fixedSize(horizontal: false, vertical: true)

            if !viewModel.subscription.isActive {
                Text(L10n.subscriptionBossPaymentHint)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(NeonTheme.outline)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let message = viewModel.expiringSoonMessage {
                SubscriptionExpiringSoonBanner(message: message)
            }
        }
    }

    private var renewalLinkSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.subscriptionPaymentLinkTitle.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundStyle(NeonTheme.primary)

            Text(L10n.subscriptionRenewalHint)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(NeonTheme.onSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                subscriptionActionButton(
                    title: L10n.share,
                    icon: "square.and.arrow.up",
                    filled: true,
                    action: shareRenewalLink
                )
                subscriptionActionButton(
                    title: L10n.copy,
                    icon: "doc.on.doc",
                    filled: false,
                    action: copyRenewalLink
                )
            }
        }
        .padding(.top, 4)
    }

    private func subscriptionActionButton(
        title: String,
        icon: String,
        filled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.5)
            }
            .foregroundStyle(filled ? NeonTheme.primary : NeonTheme.onSurfaceVariant)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(filled ? NeonTheme.primary.opacity(0.1) : NeonTheme.surfaceContainer)
            .overlay {
                Rectangle()
                    .strokeBorder(
                        (filled ? NeonTheme.primary : NeonTheme.onSurfaceVariant).opacity(filled ? 0.4 : 0.3),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private func showCopyToast(_ message: String) {
        copyToast = message
    }

    private func copyRenewalLink() {
#if os(iOS) || os(visionOS)
        guard DriverSubscriptionShare.copyLink(serviceCode: serviceCode) else { return }
        showCopyToast(L10n.subscriptionLinkCopied)
#endif
    }

    private func shareRenewalLink() {
#if os(iOS) || os(visionOS)
        DriverSubscriptionShare.share(serviceCode: serviceCode)
#endif
    }
}

#Preview {
    NavigationStack {
        DriverSubscriptionView()
            .environment(UserSession.shared)
    }
}
