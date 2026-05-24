import SwiftUI

enum NeonTheme {
    static let background = Color(hex: 0x0A0A12)
    static let surface = Color(hex: 0x0F0F1A)
    static let surfaceContainer = Color(hex: 0x141422)
    static let surfaceContainerLow = Color(hex: 0x111118)
    static let surfaceContainerHigh = Color(hex: 0x1E1E30)
    static let surfaceContainerHighest = Color(hex: 0x28283E)
    static let surfaceBright = Color(hex: 0x1A1A2E)
    static let onSurface = Color(hex: 0xE8E0F0)
    static let onSurfaceVariant = Color(hex: 0xA098B0)
    static let primary = Color(hex: 0xFF2D78)
    static let secondary = Color(hex: 0x00FFCC)
    static let outline = Color(hex: 0x5A5068)
}

extension Color {
    init(hex: UInt, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

struct NeonBackgroundView: View {
    var body: some View {
        ZStack {
            NeonTheme.background.ignoresSafeArea()

            Circle()
                .fill(NeonTheme.primary.opacity(0.10))
                .frame(width: 320, height: 320)
                .blur(radius: 120)
                .offset(x: -120, y: -280)

            Circle()
                .fill(NeonTheme.secondary.opacity(0.10))
                .frame(width: 320, height: 320)
                .blur(radius: 120)
                .offset(x: 140, y: 320)

            LinearGradient(
                colors: [.clear, NeonTheme.primary.opacity(0.30), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 1)
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}

struct NeonGlassCard<Content: View>: View {
    var accent: Color?
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(NeonTheme.surfaceContainer.opacity(0.6))
                    .background(.ultraThinMaterial.opacity(0.15))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
            }
            .shadow(color: accent?.opacity(0.15) ?? .clear, radius: 16, y: 4)
    }
}

struct NeonPrimaryButtonStyle: ButtonStyle {
    var tint: Color = NeonTheme.primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(NeonTheme.onSurface)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(configuration.isPressed ? 0.75 : 1))
            )
            .shadow(color: tint.opacity(0.35), radius: configuration.isPressed ? 4 : 12, y: 4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#if canImport(UIKit)
struct NeonFormField: View {
    let title: String
    @Binding var text: String
    let prompt: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NeonTheme.onSurface)
            TextField(prompt, text: $text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .foregroundStyle(NeonTheme.onSurface)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(NeonTheme.surfaceBright.opacity(0.8))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(NeonTheme.outline.opacity(0.5), lineWidth: 1)
                }
        }
    }
}

struct NeonPhoneFormField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NeonTheme.onSurface)
            HStack(spacing: 8) {
                Text("+90")
                    .font(.body.weight(.medium))
                    .foregroundStyle(NeonTheme.secondary)
                TextField("5321234567", text: $text)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .foregroundStyle(NeonTheme.onSurface)
                    .onChange(of: text) { _, newValue in
                        text = Self.normalizeLocalDigits(newValue)
                    }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(NeonTheme.surfaceBright.opacity(0.8))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(NeonTheme.outline.opacity(0.5), lineWidth: 1)
            }
        }
    }

    private static func normalizeLocalDigits(_ raw: String) -> String {
        var digits = raw.filter(\.isNumber)
        if digits.hasPrefix("90"), digits.count > 10 {
            digits = String(digits.dropFirst(2))
        } else if digits.hasPrefix("0"), digits.count > 10 {
            digits = String(digits.dropFirst())
        }
        return String(digits.prefix(10))
    }
}
#endif
