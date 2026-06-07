import SwiftUI

struct SettingsDeleteAccountLink: View {
    let onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(NeonTheme.outline.opacity(0.2))
                .frame(height: 1)
                .padding(.vertical, 24)
            
            Text(L10n.deleteAccount)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(hex: 0xFF4444).opacity(0.8))
                .contentShape(Rectangle())
                .onTapGesture(perform: onDelete)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 16)
    }
}
