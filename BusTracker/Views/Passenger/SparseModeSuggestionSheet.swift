import SwiftUI

struct SparseModeSuggestionSheet: View {
    let comingDays: Int
    let onConfirm: () -> Void
    let onLater: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Capsule()
                .fill(NeonTheme.surfaceContainerHighest)
                .frame(width: 48, height: 4)
                .padding(.top, 12)

            Image(systemName: "sun.haze.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color(hex: 0xFFE04A))
                .shadow(color: Color(hex: 0xFFE04A).opacity(0.45), radius: 8)

            Text(L10n.sparseModeSheetTitle)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(NeonTheme.onSurface)
                .multilineTextAlignment(.center)

            Text(L10n.sparseModeSheetMessage(comingDays: comingDays))
                .font(.subheadline)
                .foregroundStyle(NeonTheme.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            sparseActionButton(
                title: L10n.sparseModeSheetOk,
                accent: NeonTheme.secondary,
                filled: true,
                action: onConfirm
            )
            .padding(.top, 4)

            sparseActionButton(
                title: L10n.later,
                accent: NeonTheme.onSurfaceVariant,
                filled: false,
                action: onLater
            )
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity)
        .background {
            UnevenRoundedRectangle(
                topLeadingRadius: 40,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 40,
                style: .continuous
            )
            .fill(NeonTheme.surfaceContainer)
        }
    }

    private func sparseActionButton(
        title: String,
        accent: Color,
        filled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title.uppercased())
                .tracking(1)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(filled ? accent.opacity(0.18) : Color.clear)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(accent.opacity(filled ? 0.85 : 0.35), lineWidth: 2)
        }
        .buttonStyle(.plain)
    }
}
