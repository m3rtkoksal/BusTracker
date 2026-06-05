import SwiftUI

struct HolidayModeCalendarBottomSheet: View {
    let isHolidayActive: Bool
    let activeEndDateKey: String?
    @Binding var selectedEndDate: Date
    let isSaving: Bool
    let onConfirm: () -> Void
    let onEndHoliday: () -> Void
    let onDismiss: () -> Void

    @State private var dragOffset: CGFloat = 0

    private var minimumSelectableDate: Date {
        HolidayMode.calendar.startOfDay(for: Date())
    }

    private var canEndHoliday: Bool {
        isHolidayActive || (activeEndDateKey.map { HolidayMode.isActive(endDateKey: $0) } == true)
    }

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
                guard !isSaving else {
                    withAnimation(.easeOut(duration: 0.2)) { dragOffset = 0 }
                    return
                }
                if value.translation.height > 100 || value.predictedEndTranslation.height > 180 {
                    onDismiss()
                }
                withAnimation(.easeOut(duration: 0.2)) {
                    dragOffset = 0
                }
            }
    }

    private var panel: some View {
        ZStack {
            VStack(spacing: 0) {
                Capsule()
                    .fill(NeonTheme.surfaceContainerHighest)
                    .frame(width: 48, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                Image(systemName: "sun.haze.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color(hex: 0xFFE04A))
                    .shadow(color: Color(hex: 0xFFE04A).opacity(0.45), radius: 8)
                    .padding(.bottom, 16)

                Text(L10n.holidayModeTitle)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(NeonTheme.onSurface)
                    .padding(.bottom, 8)

                Text(L10n.holidayModeCalendarHint)
                    .font(.subheadline)
                    .foregroundStyle(NeonTheme.onSurfaceVariant)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 16)

                DatePicker(
                    L10n.holidayModeEndDateLabel,
                    selection: $selectedEndDate,
                    in: minimumSelectableDate...,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(NeonTheme.secondary)
                .padding(.horizontal, 4)
                .padding(.bottom, 12)
                .disabled(isSaving)

                holidayNeonButton(title: L10n.holidayModeSave, accent: NeonTheme.secondary, action: onConfirm)

                if canEndHoliday {
                    holidayNeonButton(title: L10n.holidayModeEndEarly, accent: NeonTheme.primary, action: onEndHoliday)
                        .padding(.top, 10)
                }
            }

            if isSaving {
                Color.black.opacity(0.38)
                    .allowsHitTesting(true)
                ProgressView()
                    .controlSize(.large)
                    .tint(NeonTheme.secondary)
            }
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
                    colors: [Color(hex: 0xFFE04A).opacity(0.45), Color(hex: 0xFFE04A).opacity(0.12)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
        }
        .shadow(color: Color(hex: 0xFFE04A).opacity(0.12), radius: 20, y: -6)
        .ignoresSafeArea(edges: [.bottom, .horizontal])
        .onAppear {
            if let key = activeEndDateKey, let date = HolidayMode.date(fromKey: key) {
                selectedEndDate = max(date, minimumSelectableDate)
            } else {
                selectedEndDate = minimumSelectableDate
            }
        }
    }

    private func holidayNeonButton(title: String, accent: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title.uppercased())
                .tracking(1)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(accent.opacity(isSaving ? 0.45 : 1))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(accent.opacity(isSaving ? 0.10 : 0.18))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(accent.opacity(isSaving ? 0.35 : 0.85), lineWidth: 2)
        }
        .disabled(isSaving)
        .buttonStyle(.plain)
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
