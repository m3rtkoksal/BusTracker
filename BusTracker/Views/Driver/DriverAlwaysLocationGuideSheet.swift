import SwiftUI

struct DriverAlwaysLocationGuideSheet: View {
    let waitingForSettingsReturn: Bool
    let onRequestPermission: () -> Void
    let onOpenSettings: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(NeonTheme.surfaceContainerHighest)
                .frame(width: 48, height: 4)
                .padding(.top, 12)

            Text("Servis için konum izni")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(NeonTheme.onSurface)
                .multilineTextAlignment(.center)

            Text(
                waitingForSettingsReturn
                    ? "Ayarlar açıldıysa aşağıdaki adımları uygulayın, sonra bu ekrana dönün."
                    : "Yolcular sizi haritada görebilsin diye tek seferlik izin gerekir."
            )
            .font(.subheadline)
            .foregroundStyle(NeonTheme.onSurfaceVariant)
            .multilineTextAlignment(.center)

            guideStep(number: 1, text: "Açılan pencerede Konum veya İzinler'e dokunun.")
            guideStep(number: 2, text: "\"Her zaman izin ver\" seçeneğini işaretleyin.")
            guideStep(number: 3, text: "Geri gelip Servisi başlat'a tekrar basın.")

            Button(action: onRequestPermission) {
                Text("İZİN VER")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(NeonTheme.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(NeonTheme.primary.opacity(0.15))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(NeonTheme.primary.opacity(0.45), lineWidth: 1)
            }
            .buttonStyle(.plain)

            Text("Pencere açılmadıysa")
                .font(.caption)
                .foregroundStyle(NeonTheme.onSurfaceVariant)

            Button("Ayarlara git", action: onOpenSettings)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(NeonTheme.secondary)

            Button("Vazgeç", action: onDismiss)
                .font(.footnote)
                .foregroundStyle(NeonTheme.onSurfaceVariant.opacity(0.7))
                .padding(.top, 4)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity)
        .background { sheetBackground.ignoresSafeArea(edges: .bottom) }
    }

    private func guideStep(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(NeonTheme.primary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(NeonTheme.primary.opacity(0.2)))

            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(NeonTheme.onSurface)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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
    }
}
