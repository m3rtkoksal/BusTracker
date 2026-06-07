import SwiftUI

struct SettingsNavigationRow: View {
    let title: String
    var value: String? = nil
    let action: () -> Void
    
    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(NeonTheme.onSurfaceVariant)
            
            Spacer()
            
            HStack(spacing: 4) {
                if let value {
                    Text(value)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(NeonTheme.onSurface)
                }
                
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
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
    }
}
