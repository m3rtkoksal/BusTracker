import SwiftUI

struct DriverAlwaysLocationGuideSheet: View {
    let waitingForSettingsReturn: Bool
    let onRequestPermission: () -> Void
    let onOpenSettings: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(NeonTheme.surfaceContainerHighest)
                .frame(width: 48, height: 4)
                .padding(.top, 12)

            Text(L10n.locationPermissionTitle)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(NeonTheme.onSurface)
                .multilineTextAlignment(.center)

            Text(waitingForSettingsReturn ? L10n.locationPermissionBodySettings : L10n.locationPermissionBodyInitial)
            .font(.subheadline)
            .foregroundStyle(NeonTheme.onSurfaceVariant)
            .multilineTextAlignment(.center)

            guideStep(number: 1, text: L10n.locationStep1)
            guideStep(number: 2, text: L10n.locationStep2)
            guideStep(number: 3, text: L10n.locationStep3)

            Button(action: onRequestPermission) {
                Text(L10n.grantPermission)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(NeonTheme.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(NeonTheme.primary.opacity(0.15))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(NeonTheme.primary.opacity(0.45), lineWidth: 1)
            }
            .buttonStyle(.plain)

            Text(L10n.ifWindowDidNotOpen)
                .font(.caption)
                .foregroundStyle(NeonTheme.onSurfaceVariant)

            Button(L10n.goToSettings, action: onOpenSettings)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(NeonTheme.secondary)

            Button(L10n.cancel, action: onDismiss)
                .font(.footnote)
                .foregroundStyle(NeonTheme.onSurfaceVariant.opacity(0.7))
                .padding(.top, 4)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity)
        .background { sheetBackground.ignoresSafeArea(edges: .bottom) }
    }

    private func guideStep(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(NeonTheme.primary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(NeonTheme.primary.opacity(0.2)))

            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(NeonTheme.onSurface)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var sheetBackground: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 40,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: 40,
            style: .continuous
        )
        .fill(NeonTheme.surfaceContainerLow.opacity(0.92))
    }
}
