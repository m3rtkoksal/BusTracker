import SwiftUI

struct TripStartedAttendanceSheet: View {
    let driverName: String
    let isLoading: Bool
    let selectedComing: Bool
    let selectedNotComing: Bool
    let onSelectComing: () -> Void
    let onSelectNotComing: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(NeonTheme.surfaceContainerHighest)
                .frame(width: 48, height: 4)
                .padding(.top, 12)

            Image(systemName: "bus.fill")
                .font(.system(size: 40))
                .foregroundStyle(NeonTheme.secondary)
                .shadow(color: NeonTheme.secondary.opacity(0.5), radius: 8)

            Text("Servis başladı")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(NeonTheme.onSurface)

            Text("\(driverName) servisi yola çıktı. Bugün gelecek misiniz?")
                .font(.subheadline)
                .foregroundStyle(NeonTheme.onSurfaceVariant)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                attendanceChoice(
                    title: "GELİYORUM",
                    icon: "checkmark.circle.fill",
                    accent: NeonTheme.secondary,
                    isSelected: selectedComing,
                    isLoading: isLoading && !selectedComing,
                    action: onSelectComing
                )
                attendanceChoice(
                    title: "GELMİYORUM",
                    icon: "xmark.circle.fill",
                    accent: Color(hex: 0xFF4444),
                    isSelected: selectedNotComing,
                    isLoading: isLoading && !selectedNotComing,
                    action: onSelectNotComing
                )
            }

            Text("Seçiminiz sürücüye anında iletilir.")
                .font(.caption)
                .foregroundStyle(NeonTheme.onSurfaceVariant)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity)
        .background { sheetBackground.ignoresSafeArea(edges: .bottom) }
    }

    private func attendanceChoice(
        title: String,
        icon: String,
        accent: Color,
        isSelected: Bool,
        isLoading: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                if isLoading {
                    ProgressView().tint(accent)
                } else {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(isSelected ? accent : NeonTheme.onSurfaceVariant)
                }
                Text(title)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(isSelected ? accent : NeonTheme.onSurfaceVariant)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                Rectangle()
                    .fill(isSelected ? accent.opacity(0.12) : NeonTheme.surfaceContainerHigh.opacity(0.85))
            )
            .overlay {
                Rectangle()
                    .strokeBorder(
                        isSelected ? accent.opacity(0.55) : NeonTheme.outline.opacity(0.25),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    private var sheetBackground: some View {
        UnevenRoundedRectangle(topLeadingRadius: 40, topTrailingRadius: 40)
            .fill(NeonTheme.surfaceContainer)
            .shadow(color: .black.opacity(0.35), radius: 24, y: -4)
    }
}
