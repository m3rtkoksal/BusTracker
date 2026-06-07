import SwiftUI

struct SettingsSignOutRow: View {
    let onSignOut: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "rectangle.portrait.and.arrow.right")
            Text(L10n.signOut)
                .fontWeight(.semibold)
            Spacer()
        }
        .foregroundStyle(Color(hex: 0xFF4444))
        .padding(16)
        .background(NeonTheme.surfaceContainer)
        .overlay {
            Rectangle()
                .strokeBorder(Color(hex: 0xFF4444).opacity(0.3), lineWidth: 1)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSignOut)
    }
}
