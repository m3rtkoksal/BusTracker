import SwiftUI

struct PoolPaymentView: View {
    let groupID: String
    @Bindable var viewModel: DriverSubscriptionViewModel
    @State private var contributionStore = PoolContributionStore()

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            poolModeSection
            balanceSection
            if viewModel.poolState.isPoolComplete {
                Text(L10n.poolCompleteMessage)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(NeonTheme.secondary)
                    .padding(.horizontal, 24)
            } else {
                tierSection
                payButton
                    .padding(.horizontal, 24)
            }
            if let error = contributionStore.lastError {
                Text(error)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.red.opacity(0.9))
                    .padding(.horizontal, 24)
            }
            Text(L10n.subscriptionPaymentHint)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(NeonTheme.outline)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
        }
        .task {
            await contributionStore.loadProducts()
        }
    }

    private var poolModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(L10n.poolPaymentTitle)
            HStack(spacing: 8) {
                modeButton(.monthly)
                modeButton(.annual)
            }
            .padding(.horizontal, 24)
        }
    }

    private var balanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(L10n.poolRequiredBalance)
            VStack(spacing: 10) {
                balanceRow(title: L10n.poolRequiredBalance, value: viewModel.poolState.poolTarget)
                balanceRow(title: L10n.poolPaidBalance, value: viewModel.poolState.poolCollected)
                balanceRow(
                    title: L10n.poolRemainingBalance,
                    value: viewModel.poolState.remainingBalance,
                    emphasized: true
                )
            }
            .padding(16)
            .background(NeonTheme.surfaceContainerHigh)
            .clipShape(Rectangle())
            .overlay(
                Rectangle()
                    .stroke(NeonTheme.primary.opacity(0.35), lineWidth: 1)
            )
            .padding(.horizontal, 24)
        }
    }

    private var tierSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(L10n.poolSelectAmount)
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                spacing: 8
            ) {
                ForEach(ShuttlePoolProduct.allCases) { tier in
                    tierButton(tier)
                }
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

    private func modeButton(_ mode: ShuttlePoolMode) -> some View {
        let isSelected = viewModel.poolState.poolMode == mode
        return Button {
            Task { await viewModel.setPoolMode(mode, groupID: groupID) }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(mode == .monthly ? L10n.poolModeMonthly : L10n.poolModeAnnual)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                Text(ShuttlePoolDisplay.formatCurrency(mode.targetAmount))
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                Text(mode == .monthly ? L10n.poolMonthlyHint : L10n.poolAnnualHint)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(NeonTheme.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(isSelected ? NeonTheme.primary : NeonTheme.onSurfaceVariant)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(isSelected ? NeonTheme.primary.opacity(0.12) : NeonTheme.surfaceContainer)
            .overlay {
                Rectangle()
                    .strokeBorder(
                        (isSelected ? NeonTheme.primary : NeonTheme.outline).opacity(isSelected ? 0.5 : 0.3),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private func balanceRow(title: String, value: Int, emphasized: Bool = false) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(emphasized ? NeonTheme.primary : NeonTheme.onSurfaceVariant)
            Spacer()
            Text(ShuttlePoolDisplay.formatCurrency(value))
                .font(.system(size: emphasized ? 20 : 16, weight: .heavy, design: .rounded))
                .foregroundStyle(emphasized ? NeonTheme.primary : NeonTheme.onSurface)
        }
    }

    private func tierButton(_ tier: ShuttlePoolProduct) -> some View {
        let isSelected = contributionStore.selectedTier == tier
        return Button {
            contributionStore.selectTier(tier)
        } label: {
            Text(contributionStore.displayPrice(for: tier))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? NeonTheme.background : NeonTheme.onSurface)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isSelected ? NeonTheme.primary : NeonTheme.surfaceContainer)
                .overlay {
                    Rectangle()
                        .strokeBorder(
                            isSelected ? NeonTheme.primary : NeonTheme.outline.opacity(0.35),
                            lineWidth: isSelected ? 2 : 1
                        )
                }
        }
        .buttonStyle(.plain)
    }

    private var payButton: some View {
        Button {
            Task { await purchase() }
        } label: {
            HStack(spacing: 8) {
                if contributionStore.isPurchasing {
                    ProgressView()
                        .tint(NeonTheme.background)
                }
                Text(L10n.poolPayButton.uppercased())
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(1.5)
            }
            .foregroundStyle(NeonTheme.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(contributionStore.selectedTier == nil ? NeonTheme.outline : NeonTheme.primary)
        }
        .buttonStyle(.plain)
        .disabled(contributionStore.selectedTier == nil || contributionStore.isPurchasing)
    }

    private func purchase() async {
        do {
            let result = try await contributionStore.purchaseSelectedTier(groupID: groupID)
            viewModel.applyContributionResult(result)
            viewModel.showSuccess(L10n.poolPurchaseSuccess)
            contributionStore.clearError()
            await viewModel.load(groupID: groupID, preferServer: true)
        } catch let error as PoolContributionError {
            if case .purchaseCancelled = error { return }
            contributionStore.reportError(error.localizedDescription ?? L10n.poolPurchaseBackendFailed)
        } catch {
            contributionStore.reportError(error.localizedDescription)
        }
    }
}
