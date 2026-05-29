import SwiftUI

/// Eski OTP bottom sheet kabuğu — sürücü servis süresi seçimi için kullanılır.
struct TripDurationBottomSheet: View {
    @Binding var selectedHours: Double
    let isLoading: Bool
    let canStartTrip: Bool
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    private let options: [Double] = [1, 1.5, 2, 3, 4]

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        panel
            .offset(y: dragOffset)
            .gesture(dismissDragGesture)
    }

    private var dismissDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = max(0, value.translation.height)
            }
            .onEnded { value in
                if value.translation.height > 100 || value.predictedEndTranslation.height > 180 {
                    onDismiss()
                }
                withAnimation(.easeOut(duration: 0.2)) {
                    dragOffset = 0
                }
            }
    }

    private var panel: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(NeonTheme.surfaceContainerHighest)
                .frame(width: 48, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            Image(systemName: "clock.badge.checkmark.fill")
                .font(.system(size: 40))
                .foregroundStyle(NeonTheme.primary)
                .shadow(color: NeonTheme.primary.opacity(0.5), radius: 8)
                .padding(.bottom, 16)

            Text("Servis Süresi")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(NeonTheme.onSurface)
                .padding(.bottom, 8)

            Text(
                canStartTrip
                    ? "Sefer boyunca konumunuz yolculara paylaşılır. Paylaşım süre sonunda otomatik durur."
                    : "\"Her zaman\" konum izni olmadan servis başlatılamaz. Önce İZİN VER adımlarını tamamlayın."
            )
            .font(.subheadline)
            .foregroundStyle(canStartTrip ? NeonTheme.onSurfaceVariant : Color(hex: 0xFF4444))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
            .padding(.bottom, 20)

            durationGrid
                .padding(.bottom, 20)

            Button(action: onConfirm) {
                Group {
                    if isLoading {
                        ProgressView().tint(NeonTheme.primary)
                    } else {
                        Text("SERVİSİ BAŞLAT")
                            .tracking(1.5)
                    }
                }
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(NeonTheme.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(NeonTheme.surfaceContainerHigh)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(NeonTheme.primary.opacity(0.5), lineWidth: 1)
            }
            .disabled(isLoading || !canStartTrip)
            .opacity(canStartTrip ? 1 : 0.45)
            .buttonStyle(.plain)
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 28)
        .safeAreaPadding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background { sheetBackground.ignoresSafeArea(edges: .bottom) }
        .overlay {
            UnevenRoundedRectangle(
                topLeadingRadius: 40,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 40,
                style: .continuous
            )
            .strokeBorder(
                LinearGradient(
                    colors: [NeonTheme.primary.opacity(0.45), NeonTheme.primary.opacity(0.12)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
        }
        .shadow(color: NeonTheme.primary.opacity(0.12), radius: 20, y: -6)
        .ignoresSafeArea(edges: [.bottom, .horizontal])
    }

    private var durationGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(options, id: \.self) { hours in
                Button {
                    selectedHours = hours
                } label: {
                    Text(durationLabel(hours))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(selectedHours == hours ? NeonTheme.primary : NeonTheme.onSurfaceVariant)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(
                                    selectedHours == hours
                                        ? NeonTheme.primary.opacity(0.14)
                                        : NeonTheme.surfaceContainerHigh.opacity(0.85)
                                )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(
                                    selectedHours == hours
                                        ? NeonTheme.primary.opacity(0.55)
                                        : NeonTheme.outline.opacity(0.3),
                                    lineWidth: selectedHours == hours ? 2 : 1
                                )
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func durationLabel(_ hours: Double) -> String {
        hours == floor(hours) ? "\(Int(hours)) saat" : "\(hours) saat"
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
        .background {
            UnevenRoundedRectangle(
                topLeadingRadius: 40,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 40,
                style: .continuous
            )
            .fill(.ultraThinMaterial.opacity(0.35))
        }
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        NeonBackgroundView()
        TripDurationBottomSheet(
            selectedHours: .constant(2),
            isLoading: false,
            canStartTrip: true,
            onConfirm: {},
            onDismiss: {}
        )
    }
}
