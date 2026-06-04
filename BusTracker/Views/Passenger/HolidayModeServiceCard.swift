import SwiftUI

private enum HolidayModeCardStyle {
    static let accent = Color(hex: 0xFFE04A)
    static let accentMuted = Color(hex: 0xFFE04A).opacity(0.14)
}

struct HolidayModeServiceCard: View {
    let isActive: Bool
    let subtitle: String
    let detailLine: String
    @Binding var showPicker: Bool

    var body: some View {
        Button {
            showPicker = true
        } label: {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(HolidayModeCardStyle.accentMuted)
                        .frame(width: 44, height: 44)
                    Image(systemName: "sun.haze.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(HolidayModeCardStyle.accent)
                        .shadow(color: HolidayModeCardStyle.accent.opacity(0.45), radius: 6)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(L10n.holidayModeTitle.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(1.8)
                            .foregroundStyle(HolidayModeCardStyle.accent)

                        if isActive {
                            Text(L10n.holidayModeBadgeActive)
                                .font(.system(size: 8, weight: .heavy, design: .rounded))
                                .tracking(0.8)
                                .foregroundStyle(NeonTheme.background)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(HolidayModeCardStyle.accent))
                        }
                    }

                    Text(subtitle)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(NeonTheme.onSurface)

                    Text(detailLine)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(NeonTheme.onSurfaceVariant)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(HolidayModeCardStyle.accent.opacity(0.85))
                    .padding(.top, 4)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack {
                    NeonTheme.surfaceContainer
                    LinearGradient(
                        colors: [
                            HolidayModeCardStyle.accent.opacity(isActive ? 0.12 : 0.06),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(HolidayModeCardStyle.accent)
                    .frame(width: 3)
            }
            .overlay {
                Rectangle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                HolidayModeCardStyle.accent.opacity(isActive ? 0.55 : 0.35),
                                HolidayModeCardStyle.accent.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: HolidayModeCardStyle.accent.opacity(isActive ? 0.18 : 0.08), radius: 10, y: 3)
        }
        .buttonStyle(.plain)
    }
}

struct HolidayModePickerOverlay: View {
    @Binding var isPresented: Bool
    let isHolidayActive: Bool
    let activeEndDateKey: String?
    @Binding var selectedEndDate: Date
    let isSaving: Bool
    let onConfirm: () -> Void
    let onEndHoliday: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            HolidayModeCalendarBottomSheet(
                isHolidayActive: isHolidayActive,
                activeEndDateKey: activeEndDateKey,
                selectedEndDate: $selectedEndDate,
                isSaving: isSaving,
                onConfirm: onConfirm,
                onEndHoliday: onEndHoliday,
                onDismiss: { isPresented = false }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .ignoresSafeArea(edges: .bottom)
    }
}
