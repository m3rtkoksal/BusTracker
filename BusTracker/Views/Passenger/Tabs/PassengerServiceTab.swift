import CoreLocation
import SwiftUI

struct PassengerServiceTab: View {
    @Environment(ShuttleStore.self) private var store
    @Bindable var viewModel: PassengerHomeViewModel
    let nextTwoServices: [UpcomingService]
    let isHolidayModeActive: Bool
    let holidayModeCardSubtitle: String
    let holidayModeCardDetail: String
    let savedMorningPickup: MorningPickup?
    @Binding var showComingBlockedWithoutPickupHint: Bool
    @Binding var showHolidayModePicker: Bool
    @Binding var pickupWeather: PassengerWeatherCardModel?
    @Binding var pickupWeatherLoading: Bool
    
    let onRequestComingAttendance: (UpcomingService) -> Void
    let onRequestNotComingAttendance: (UpcomingService) -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let delayMinutes = serviceDelayMinutes {
                    serviceDelayNoticeSection(minutes: delayMinutes)
                }
                attendanceSection
                if !notComingPassengers.isEmpty {
                    notComingPassengersSection
                }
                holidayModeSection
                if weatherAdvisory != nil {
                    clothingAdviceSection
                }
            }
            .padding(24)
        }
    }
    
    // MARK: - Service Delay

    private var nearestUpcomingService: UpcomingService {
        viewModel.nearestUpcomingService
    }

    private var serviceDelayMinutes: Int? {
        _ = store.delayNoticeRevision
        return store.delayNoticeMinutes(for: nearestUpcomingService.dateKey)
    }

    private func serviceDelayNoticeSection(minutes: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.badge.exclamationmark.fill")
                .font(.system(size: 22))
                .foregroundStyle(Color(hex: 0xFFE04A))
                .shadow(color: Color(hex: 0xFFE04A).opacity(0.5), radius: 6)

            Text(L10n.passengerServiceDelayed(minutes))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(NeonTheme.onSurface)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(hex: 0xFFE04A).opacity(0.1))
        .clipShape(Rectangle())
        .overlay {
            Rectangle()
                .strokeBorder(Color(hex: 0xFFE04A).opacity(0.45), lineWidth: 1.5)
        }
    }

    // MARK: - Attendance Section
    
    private var attendanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(nextTwoServices, id: \.dateKey) { service in
                serviceAttendanceCard(for: service)
            }
            
            Text(isHolidayModeActive ? L10n.attendanceHolidayHint : L10n.attendanceHint)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .tracking(1)
                .foregroundStyle(NeonTheme.outline)
                .frame(maxWidth: .infinity, alignment: .center)
            
            if showComingBlockedWithoutPickupHint {
                Text(L10n.comingBlockedWithoutPickup)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.6)
                    .foregroundStyle(NeonTheme.error)
                    .shadow(color: NeonTheme.error.opacity(0.75), radius: 8)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(16)
        .background(NeonTheme.surfaceContainer)
        .clipShape(Rectangle())
        .overlay {
            Rectangle()
                .strokeBorder(NeonTheme.secondary.opacity(0.22), lineWidth: 1)
        }
    }
    
    @ViewBuilder
    private func serviceAttendanceCard(for service: UpcomingService) -> some View {
        let raw = viewModel.rawAttendance(for: service)
        let effective = viewModel.effectiveAttendance(for: service)
        let showChoice = raw != .unknown || (isHolidayModeActive && effective != .unknown)
        let choiceStatus: AttendanceStatus = raw != .unknown ? raw : effective
        
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(service.session.icon)
                    .font(.system(size: 16))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(service.relativeDisplayName().uppercased())
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(NeonTheme.onSurface)
                    
                    Text(service.displayDate)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(NeonTheme.onSurfaceVariant)
                }
                
                Spacer()
                
                if showChoice {
                    HStack(spacing: 4) {
                        Image(systemName: choiceStatus.iconName)
                            .font(.system(size: 12))
                        Text(choiceStatus.selfChoiceLabel)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(attendanceColor(choiceStatus))
                }
            }
            
            HStack(spacing: 8) {
                attendanceButton(
                    title: L10n.attendanceComingSelf,
                    icon: "checkmark.circle.fill",
                    accent: NeonTheme.secondary,
                    status: .coming,
                    isSelected: viewModel.isComingSelected(for: service),
                    service: service
                )
                attendanceButton(
                    title: L10n.attendanceNotComingSelf,
                    icon: "xmark.circle.fill",
                    accent: Color(hex: 0xFF4444),
                    status: .notComing,
                    isSelected: viewModel.isNotComingSelected(for: service),
                    service: service
                )
            }
        }
        .padding(16)
        .background(NeonTheme.surfaceContainer.opacity(0.6))
        .clipShape(Rectangle())
        .overlay {
            Rectangle()
                .strokeBorder(NeonTheme.outline.opacity(0.15), lineWidth: 1)
        }
    }
    
    private func attendanceButton(
        title: String,
        icon: String,
        accent: Color,
        status: AttendanceStatus,
        isSelected: Bool,
        service: UpcomingService
    ) -> some View {
        Button {
            if status == .coming {
                onRequestComingAttendance(service)
            } else {
                onRequestNotComingAttendance(service)
            }
        } label: {
            VStack(spacing: 6) {
                if viewModel.isUpdatingAttendance && !isSelected {
                    ProgressView().tint(accent)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .shadow(color: isSelected ? accent.opacity(0.65) : .clear, radius: 6)
                }
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1)
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? accent : NeonTheme.onSurfaceVariant)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(isSelected ? accent.opacity(0.12) : NeonTheme.surfaceContainerHigh.opacity(0.85))
            .clipShape(Rectangle())
            .overlay {
                Rectangle()
                    .strokeBorder(isSelected ? accent.opacity(0.55) : NeonTheme.outline.opacity(0.25), lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Holiday Mode Section
    
    private var holidayModeSection: some View {
        HolidayModeServiceCard(
            isActive: isHolidayModeActive,
            subtitle: holidayModeCardSubtitle,
            detailLine: holidayModeCardDetail,
            showPicker: $showHolidayModePicker
        )
    }
    
    // MARK: - Not Coming Passengers Section

    private var notComingPassengers: [ShuttleMember] {
        _ = store.attendanceRevision
        return viewModel.notComingPassengers(for: nearestUpcomingService)
    }

    private var notComingPassengersSection: some View {
        let service = nearestUpcomingService

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(service.session.icon)
                    .font(.system(size: 16))

                Text(L10n.serviceNotComingListTitle(service.relativeDisplayName()).uppercased())
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(NeonTheme.onSurface)
            }

            VStack(spacing: 8) {
                ForEach(notComingPassengers) { member in
                    HStack(spacing: 12) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color(hex: 0xFF4444))

                        Text(member.name)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(NeonTheme.onSurface)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(NeonTheme.surfaceContainer.opacity(0.6))
                    .overlay {
                        Rectangle()
                            .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NeonTheme.surfaceContainer)
        .overlay {
            Rectangle()
                .strokeBorder(NeonTheme.primary.opacity(0.7), lineWidth: 1.5)
        }
        .shadow(color: NeonTheme.primary.opacity(0.12), radius: 6)
    }

    // MARK: - Clothing Advice Section

    private var weatherAdvisory: PassengerWeatherAdvisoryContext? {
        PassengerWeatherService.advisoryContext()
    }

    private var weatherCoordinate: CLLocationCoordinate2D? {
        savedMorningPickup?.coordinate ?? viewModel.draftPickupCoordinate
    }
    
    private var clothingAdviceSection: some View {
        PassengerWeatherCard(
            model: pickupWeather,
            isLoading: weatherCoordinate != nil && pickupWeatherLoading,
            emptyMessage: weatherCoordinate == nil ? L10n.weatherNeedsPickup : nil
        )
        .task(id: pickupWeatherTaskKey) {
            await refreshPickupWeather()
        }
    }
    
    private var pickupWeatherTaskKey: String {
        guard let coordinate = weatherCoordinate,
              let advisory = weatherAdvisory
        else { return "none" }
        return "\(coordinate.latitude),\(coordinate.longitude),\(advisory.targetMorningKey)"
    }
    
    private func refreshPickupWeather() async {
        guard let coordinate = weatherCoordinate,
              let advisory = weatherAdvisory
        else {
            pickupWeather = nil
            pickupWeatherLoading = false
            return
        }
        if let cached = PassengerWeatherService.cachedModel(for: coordinate, advisory: advisory) {
            pickupWeather = cached
            return
        }
        pickupWeatherLoading = true
        defer { pickupWeatherLoading = false }
        pickupWeather = await PassengerWeatherService.load(for: coordinate, advisory: advisory)
    }
    
    // MARK: - Helpers
    
    private func attendanceColor(_ status: AttendanceStatus) -> Color {
        switch status {
        case .coming: return NeonTheme.secondary
        case .notComing: return Color(hex: 0xFF4444)
        case .unknown: return Color(hex: 0xFFE04A)
        }
    }
}
