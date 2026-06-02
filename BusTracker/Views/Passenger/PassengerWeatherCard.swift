import SwiftUI

struct PassengerWeatherCard: View {
    let model: PassengerWeatherCardModel?
    var isLoading: Bool = false
    var emptyMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.clothingAdvice)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(NeonTheme.onSurfaceVariant)

            if let model {
                HStack(alignment: .top, spacing: 12) {
                    Text(model.emoji)
                        .font(.system(size: 28))

                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.advice)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(NeonTheme.onSurface)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(model.contextLine)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(NeonTheme.onSurfaceVariant)
                    }
                }
            } else if isLoading {
                Text(L10n.weatherLoading)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(NeonTheme.onSurfaceVariant)
            } else if let emptyMessage {
                Text(emptyMessage)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(NeonTheme.onSurfaceVariant)
            } else {
                Text(L10n.weatherUnavailable)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(NeonTheme.onSurfaceVariant)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NeonTheme.surfaceContainer)
        .clipShape(Rectangle())
        .overlay {
            Rectangle()
                .strokeBorder(NeonTheme.secondary.opacity(0.22), lineWidth: 1)
        }
    }
}
