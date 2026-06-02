import SwiftUI

struct LanguagePickerBottomSheet: View {
    let selectedLanguage: AppLanguage
    let onSelect: (AppLanguage) -> Void
    let onDismiss: () -> Void

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        panel
            .offset(y: dragOffset)
            .gesture(dismissDragGesture)
    }

    private var dismissDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = max(0, value.translation.height)
            }
            .onEnded { value in
                if value.translation.height > 100 || value.predictedEndTranslation.height > 180 {
                    onDismiss()
                }
                withAnimation(.easeOut(duration: 0.2)) {
                    dragOffset = 0
                }
            }
    }

    private var panel: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(NeonTheme.surfaceContainerHighest)
                .frame(width: 48, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            Image(systemName: "globe")
                .font(.system(size: 40))
                .foregroundStyle(NeonTheme.secondary)
                .shadow(color: NeonTheme.secondary.opacity(0.5), radius: 8)
                .padding(.bottom, 16)

            Text(L10n.settingsLanguage)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(NeonTheme.onSurface)
                .padding(.bottom, 20)

            VStack(spacing: 10) {
                ForEach(AppLanguage.allCases) { language in
                    languageOption(language)
                }
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 28)
        .safeAreaPadding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background { sheetBackground.ignoresSafeArea(edges: .bottom) }
        .overlay {
            UnevenRoundedRectangle(
                topLeadingRadius: 40,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 40,
                style: .continuous
            )
            .strokeBorder(
                LinearGradient(
                    colors: [NeonTheme.secondary.opacity(0.45), NeonTheme.secondary.opacity(0.12)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
        }
        .shadow(color: NeonTheme.secondary.opacity(0.12), radius: 20, y: -6)
        .ignoresSafeArea(edges: [.bottom, .horizontal])
    }

    private func languageOption(_ language: AppLanguage) -> some View {
        let isSelected = language == selectedLanguage

        return Button {
            onSelect(language)
        } label: {
            HStack(spacing: 12) {
                Text(language.displayName)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? NeonTheme.secondary : NeonTheme.onSurface)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(NeonTheme.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        isSelected
                            ? NeonTheme.secondary.opacity(0.14)
                            : NeonTheme.surfaceContainerHigh.opacity(0.85)
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isSelected
                            ? NeonTheme.secondary.opacity(0.55)
                            : NeonTheme.outline.opacity(0.3),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
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
        .background {
            UnevenRoundedRectangle(
                topLeadingRadius: 40,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 40,
                style: .continuous
            )
            .fill(.ultraThinMaterial.opacity(0.35))
        }
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        NeonBackgroundView()
        LanguagePickerBottomSheet(
            selectedLanguage: .turkish,
            onSelect: { _ in },
            onDismiss: {}
        )
    }
}
