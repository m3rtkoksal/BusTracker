import SwiftUI

struct LanguageSettingsRow: View {
    @Environment(LanguageManager.self) private var languageManager
    @Binding var showPicker: Bool

    var body: some View {
        Button {
            showPicker = true
        } label: {
            HStack {
                Text(L10n.settingsLanguage.uppercased())
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(NeonTheme.onSurfaceVariant)

                Spacer()

                HStack(spacing: 4) {
                    Text(languageManager.language.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(NeonTheme.onSurface)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NeonTheme.onSurfaceVariant)
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
    }
}

struct LanguagePickerOverlay: View {
    @Environment(LanguageManager.self) private var languageManager
    @Binding var isPresented: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            LanguagePickerBottomSheet(
                selectedLanguage: languageManager.language,
                onSelect: { language in
                    languageManager.setLanguage(language)
                    isPresented = false
                },
                onDismiss: { isPresented = false }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .ignoresSafeArea(edges: .bottom)
    }
}
