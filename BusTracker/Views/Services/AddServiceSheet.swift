import SwiftUI

struct AddServiceSheet: View {
    @Binding var serviceCode: String
    let isLoading: Bool
    let errorText: String?
    let onJoin: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(NeonTheme.surfaceContainerHighest)
                .frame(width: 48, height: 4)
                .padding(.top, 12)

            Text("Yeni servis ekle")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(NeonTheme.onSurface)

            Text("Sürücünün verdiği servis kodunu girin. Ekledikten sonra bu servis aktif olur.")
                .font(.subheadline)
                .foregroundStyle(NeonTheme.onSurfaceVariant)
                .multilineTextAlignment(.center)

            NeonFormField(
                title: "Servis kodu",
                text: $serviceCode,
                prompt: "6 haneli kod",
                keyboard: .asciiCapable,
                textInputAutocapitalization: .characters,
                errorText: errorText
            )

            Button(action: onJoin) {
                Group {
                    if isLoading {
                        ProgressView().tint(NeonTheme.secondary)
                    } else {
                        Text("SERVİSE KATIL")
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
            .disabled(isLoading || serviceCode.trimmingCharacters(in: .whitespacesAndNewlines).count < 4)

            Button("Vazgeç", action: onDismiss)
                .font(.footnote)
                .foregroundStyle(NeonTheme.onSurfaceVariant.opacity(0.7))
                .padding(.top, 4)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 40, topTrailingRadius: 40)
                .fill(NeonTheme.surfaceContainer)
                .shadow(color: .black.opacity(0.35), radius: 24, y: -4)
                .ignoresSafeArea(edges: .bottom)
        }
    }
}
