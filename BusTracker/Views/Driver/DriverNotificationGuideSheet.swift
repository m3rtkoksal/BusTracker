import SwiftUI

enum DriverNotificationGuidePhase: Equatable {
    case guide
    case waitingSettingsReturn
}

struct DriverNotificationGuideSheet: View {
    let phase: DriverNotificationGuidePhase
    let bodyGuide: String
    let onOpenSettings: () -> Void
    let onDismiss: () -> Void

    init(
        phase: DriverNotificationGuidePhase,
        bodyGuide: String = L10n.driverNotificationPermissionBody,
        onOpenSettings: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.phase = phase
        self.bodyGuide = bodyGuide
        self.onOpenSettings = onOpenSettings
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(NeonTheme.surfaceContainerHighest)
                .frame(width: 48, height: 4)
                .padding(.top, 12)

            Text(L10n.notificationsDisabledTitle)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(NeonTheme.onSurface)
                .multilineTextAlignment(.center)

            Text(bodyText)
                .font(.subheadline)
                .foregroundStyle(NeonTheme.onSurfaceVariant)
                .multilineTextAlignment(.center)

            ForEach(Array(steps.enumerated()), id: \.offset) { index, text in
                guideStep(number: index + 1, text: text)
            }

            actionButton(title: L10n.goToSettings, action: onOpenSettings)

            Button(L10n.cancel, action: onDismiss)
                .font(.footnote)
                .foregroundStyle(NeonTheme.onSurfaceVariant.opacity(0.7))
                .padding(.top, 4)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity)
        .background { sheetBackground.ignoresSafeArea(edges: .bottom) }
        .animation(.easeInOut(duration: 0.22), value: phase)
    }

    private var bodyText: String {
        switch phase {
        case .guide:
            bodyGuide
        case .waitingSettingsReturn:
            L10n.notificationPermissionBodySettings
        }
    }

    private var steps: [String] {
        [L10n.notificationSettingsStep1, L10n.notificationSettingsStep2, L10n.notificationSettingsStep3]
    }

    private func actionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
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
