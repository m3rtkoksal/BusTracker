import SwiftUI

struct AddServiceSheet: View {
    @Binding var serviceCode: String
    let isLoading: Bool
    let errorText: String?
    let onJoin: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Rectangle()
                .fill(NeonTheme.surfaceContainerHighest)
                .frame(width: 48, height: 4)
                .padding(.top, 12)

            Text(L10n.addShuttleTitle)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(NeonTheme.onSurface)

            Text(L10n.addShuttleBody)
                .font(.subheadline)
                .foregroundStyle(NeonTheme.onSurfaceVariant)
                .multilineTextAlignment(.center)

            NeonFormField(
                title: L10n.serviceCodeField,
                text: $serviceCode,
                prompt: L10n.sixDigitCode,
                keyboard: .asciiCapable,
                textInputAutocapitalization: .characters,
                errorText: errorText,
                cornerRadius: 0
            )

            Button(action: onJoin) {
                Group {
                    if isLoading {
                        ProgressView().tint(NeonTheme.secondary)
                    } else {
                        Text(L10n.joinShuttle)
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .tracking(1.2)
                            .foregroundStyle(NeonTheme.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
            }
            .background(
                Rectangle()
                    .fill(NeonTheme.secondary.opacity(0.15))
            )
            .overlay {
                Rectangle()
                    .strokeBorder(NeonTheme.secondary.opacity(0.45), lineWidth: 1)
            }
            .buttonStyle(.plain)
            .clipShape(Rectangle())
            .disabled(isLoading || serviceCode.trimmingCharacters(in: .whitespacesAndNewlines).count < 4)

            Button(L10n.cancel, action: onDismiss)
                .font(.footnote)
                .foregroundStyle(NeonTheme.onSurfaceVariant.opacity(0.7))
                .padding(.top, 4)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity)
        .background {
            Rectangle()
                .fill(NeonTheme.surfaceContainer)
                .shadow(color: .black.opacity(0.35), radius: 24, y: -4)
                .ignoresSafeArea(edges: .bottom)
        }
    }
}
