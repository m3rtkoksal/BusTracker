import SwiftUI

struct SettingsServiceCodeRow: View {
    let code: String
    let onCopy: () -> Void
    
    var body: some View {
        HStack {
            Text(L10n.settingsServiceCode.uppercased())
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(NeonTheme.onSurfaceVariant)
            
            Spacer()
            
            Text(code)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(NeonTheme.secondary)
        }
        .padding(16)
        .background(NeonTheme.surfaceContainer)
        .overlay {
            Rectangle()
                .strokeBorder(NeonTheme.outline.opacity(0.3), lineWidth: 1)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onCopy)
    }
}
