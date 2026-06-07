import SwiftUI

struct SettingsDeleteAccountFooter: View {
    let onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(NeonTheme.outline.opacity(0.25))
                .frame(height: 1)
            
            Button(action: onDelete) {
                HStack {
                    Image(systemName: "trash")
                    Text(L10n.deleteAccount)
                        .fontWeight(.semibold)
                        .textCase(.uppercase)
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(16)
                .background(Color(hex: 0xFF4444))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .background(NeonTheme.background)
    }
}
