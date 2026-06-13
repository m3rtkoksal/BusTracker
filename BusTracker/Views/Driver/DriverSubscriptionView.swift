import SwiftUI

struct DriverSubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(UserSession.self) private var session
    @State private var viewModel = DriverSubscriptionViewModel()

    private var groupID: String {
        session.profile?.primaryGroupID ?? ""
    }

    var body: some View {
        ZStack(alignment: .top) {
            ZStack {
                NeonTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar

                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            titleSection
                            statusSection

                            membershipDatesSection

                            PoolPaymentView(groupID: groupID, viewModel: viewModel)
                        }
                        .padding(.bottom, 32)
                    }
                }
            }

            if let toast = viewModel.toast {
                TopToastBanner(popup: toast, onDismiss: viewModel.clearToast)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .animation(.easeInOut(duration: 0.25), value: viewModel.toast?.id)
        .task(id: groupID) {
            await viewModel.load(groupID: groupID)
        }
        .task(id: viewModel.toast?.id) {
            guard viewModel.toast != nil else { return }
            try? await Task.sleep(for: .seconds(3))
            viewModel.clearToast()
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .tint(NeonTheme.secondary)
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(NeonTheme.secondary)
                    .padding(10)
                    .background(NeonTheme.surfaceContainer)
                    .clipShape(Rectangle())
                    .overlay(
                        Rectangle()
                            .stroke(NeonTheme.secondary.opacity(0.35), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(NeonTheme.surface.opacity(0.8))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(NeonTheme.primary.opacity(0.2))
                .frame(height: 1)
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.subscription)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(NeonTheme.onSurface)
                .tracking(1)

            Rectangle()
                .fill(NeonTheme.primary)
                .frame(width: 48, height: 4)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let message = viewModel.expiringSoonMessage {
                SubscriptionExpiringSoonBanner(message: message)
                    .padding(.horizontal, 24)
            }

            Text(statusDescription)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(NeonTheme.onSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
        }
    }

    private var membershipDatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(L10n.subscriptionSectionTitle)

            VStack(spacing: 12) {
                membershipDateRow(title: L10n.subscriptionStartDate, value: viewModel.startDateText)
                membershipDateRow(title: L10n.subscriptionEndDate, value: viewModel.endDateText)
            }
            .padding(.horizontal, 24)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(NeonTheme.primary)
                .frame(width: 3, height: 14)
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(NeonTheme.onSurfaceVariant)
        }
        .padding(.horizontal, 24)
    }

    private func membershipDateRow(title: String, value: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(NeonTheme.onSurfaceVariant)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(NeonTheme.onSurface)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(NeonTheme.surfaceContainer)
        .clipShape(Rectangle())
        .overlay(
            Rectangle()
                .stroke(NeonTheme.onSurface.opacity(0.06), lineWidth: 1)
        )
    }

    private var statusDescription: String {
        if viewModel.poolState.subscription.isInGracePeriod {
            return L10n.subscriptionGraceDescription
        }
        if viewModel.poolState.isServiceOperational {
            return L10n.subscriptionActiveDescription
        }
        return L10n.subscriptionInactiveDescription
    }
}

#Preview {
    DriverSubscriptionView()
        .environment(UserSession.shared)
}
