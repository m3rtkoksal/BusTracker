import SwiftUI

struct NeonRoleCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            NeonGlassCard(accent: accent) {
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(accent.opacity(0.12))
                            .frame(width: 88, height: 88)
                        Circle()
                            .strokeBorder(accent.opacity(0.25), lineWidth: 1)
                            .frame(width: 88, height: 88)
                        Image(systemName: icon)
                            .font(.system(size: 40))
                            .foregroundStyle(accent)
                            .shadow(color: accent.opacity(0.7), radius: 8)
                    }

                    Text(title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(NeonTheme.onSurface)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(NeonTheme.onSurfaceVariant)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .frame(maxWidth: 260)

                    HStack(spacing: 6) {
                        Text("SEÇ VE DEVAM ET")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .tracking(1.5)
                        Image(systemName: "arrow.right")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(accent)
                    .padding(.top, 4)
                }
                .padding(28)
                .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.plain)
    }
}

struct NeonRegistrationHero: View {
    let icon: String
    let title: String
    let subtitle: String
    let accent: Color

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.12))
                    .frame(width: 120, height: 120)
                    .blur(radius: 30)

                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(accent.opacity(0.08))
                    .frame(width: 80, height: 80)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(accent.opacity(0.3), lineWidth: 1)
                    }
                Image(systemName: icon)
                    .font(.system(size: 36))
                    .foregroundStyle(accent)
                    .shadow(color: accent.opacity(0.6), radius: 10)
            }

            Text(title)
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(NeonTheme.onSurface)
                .shadow(color: NeonTheme.primary.opacity(0.4), radius: 8)

            HStack(spacing: 8) {
                Rectangle()
                    .fill(NeonTheme.onSurfaceVariant.opacity(0.3))
                    .frame(width: 32, height: 1)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(NeonTheme.onSurfaceVariant)
                Rectangle()
                    .fill(NeonTheme.onSurfaceVariant.opacity(0.3))
                    .frame(width: 32, height: 1)
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

struct RegistrationBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.left")
                Text("ROL SEÇİMİNE DÖN")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(2)
            }
            .foregroundStyle(NeonTheme.onSurfaceVariant)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
}
