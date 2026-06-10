import SwiftUI

struct SubscriptionExpiringSoonBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(Color(hex: 0xFFE04A))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(NeonTheme.surfaceContainer)
            .overlay {
                Rectangle()
                    .strokeBorder(Color(hex: 0xFFE04A).opacity(0.45), lineWidth: 1)
            }
    }
}
