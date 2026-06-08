import MapKit
import SwiftUI

struct PassengerMapTab: View {
    @Environment(ShuttleStore.self) private var store
    @Bindable var viewModel: PassengerHomeViewModel
    let savedMorningPickup: MorningPickup?
    let hasSavedMorningPickup: Bool
    let currentServiceEffectiveAttendance: AttendanceStatus
    let onSelectServiceTab: () -> Void
    let onSavePickup: () -> Void
    
    @Binding var mapPosition: MapCameraPosition
    var onCameraRegionChange: ((MKCoordinateRegion) -> Void)?
    
    // MARK: - Map Focus Actions
    var focusOnSavedPickupOrDevice: ((Bool) -> Void)?
    var focusOnDriverLocation: ((Bool) -> Void)?
    
    var body: some View {
        ZStack {
            PassengerLiveMap(
                driverLocation: store.driverLocation,
                driverRoute: store.driverRoute,
                canonicalMorningRoute: store.canonicalMorningRoute,
                isTripActive: store.isTripActive,
                selectedCoordinate: $viewModel.draftPickupCoordinate,
                savedPickup: savedMorningPickup,
                cameraPosition: $mapPosition,
                isActive: true,
                autoFitOnAppear: false,
                onCameraRegionChange: { onCameraRegionChange?($0) }
            )
            .ignoresSafeArea()
            
            NeonMapOverlay()
            
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    compactTopInfo
                    
                    Spacer(minLength: 0)
                    
                    if store.isTripActive {
                        liveBadge
                    }
                    
                    mapControls
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                Spacer(minLength: 0)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !hasSavedMorningPickup || viewModel.draftPickupCoordinate != nil {
                mapPickupBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
        }
    }
    
    // MARK: - Compact Info
    
    private var compactTopInfo: some View {
        VStack(alignment: .leading, spacing: 3) {
            compactServiceInfoBox
            compactAttendanceInfoBox
        }
    }
    
    private var compactServiceInfoBox: some View {
        let isServiceLive = store.isTripActive
        let accent = isServiceLive ? NeonTheme.secondary : NeonTheme.outline
        
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(accent)
                    .frame(width: 6, height: 6)
                    .shadow(
                        color: isServiceLive ? accent.opacity(0.8) : .clear,
                        radius: isServiceLive ? 4 : 0
                    )
                Text((viewModel.profile?.groupName ?? L10n.service).uppercased())
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(isServiceLive ? NeonTheme.onSurface : NeonTheme.onSurfaceVariant)
                    .lineLimit(1)
            }
            
            if isServiceLive, let location = store.driverLocation {
                Text("\(location.driverName.uppercased()) • \(location.updatedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(NeonTheme.secondary)
                    .lineLimit(1)
            } else {
                Text(isServiceLive ? L10n.waitingForLocation : L10n.shuttleInactive)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(NeonTheme.onSurfaceVariant.opacity(isServiceLive ? 1 : 0.85))
                    .lineLimit(1)
            }
        }
        .opacity(isServiceLive ? 1 : 0.88)
        .mapInfoBoxStyle(accent: accent)
    }
    
    private var compactAttendanceInfoBox: some View {
        let myMember = viewModel.myMember
        let isBoarded = myMember?.isBoardedToday == true
        let accent = isBoarded ? NeonTheme.secondary : attendanceColor(currentServiceEffectiveAttendance)
        let label = currentServiceEffectiveAttendance.mapTabLabel(isBoarded: isBoarded)
        let icon = isBoarded ? "bus.fill" : currentServiceEffectiveAttendance.iconName
        
        return Button {
            onSelectServiceTab()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Text(L10n.change)
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .tracking(0.5)
                    .foregroundStyle(NeonTheme.onSurfaceVariant)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(accent)
            .padding(.leading, 10)
            .padding(.trailing, 8)
            .padding(.vertical, 7)
            .background(accent.opacity(0.14))
            .background(NeonTheme.surfaceContainer.opacity(0.5))
            .fixedSize(horizontal: true, vertical: false)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(accent)
                    .frame(width: 2)
            }
            .overlay {
                Rectangle()
                    .strokeBorder(accent.opacity(0.48), lineWidth: 1)
            }
            .shadow(color: accent.opacity(0.2), radius: 4, y: 1)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Map Controls
    
    private var showsDriverMapButton: Bool {
        store.isTripActive && store.driverLocation != nil
    }
    
    private var mapControls: some View {
        VStack(spacing: 8) {
            mapControlButton(
                icon: savedMorningPickup != nil ? "pin.fill" : "pin",
                highlighted: true,
                iconColor: NeonTheme.secondary
            ) {
                focusOnSavedPickupOrDevice?(true)
            }
            if showsDriverMapButton {
                mapControlButton(
                    icon: "bus.fill",
                    highlighted: true,
                    iconColor: NeonTheme.mapDriverPin
                ) {
                    focusOnDriverLocation?(true)
                }
            }
        }
    }
    
    private func mapControlButton(
        icon: String,
        highlighted: Bool = false,
        compact: Bool = false,
        iconColor: Color? = nil,
        action: @escaping () -> Void
    ) -> some View {
        let tint = iconColor ?? (highlighted ? NeonTheme.secondary : NeonTheme.onSurface)
        let borderColor = iconColor ?? (highlighted ? NeonTheme.secondary : NeonTheme.outline)
        return Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: compact ? 15 : 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: compact ? 32 : 40, height: compact ? 32 : 40)
                .background(NeonTheme.surfaceContainer.opacity(0.92))
                .overlay {
                    Rectangle()
                        .strokeBorder(borderColor.opacity(highlighted ? 0.55 : 0.3), lineWidth: 1)
                }
                .shadow(color: tint.opacity(0.25), radius: 6)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Pickup Bar
    
    private var mapPickupBar: some View {
        VStack(spacing: 8) {
            Text(L10n.tapMapToSelectPickup)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(NeonTheme.onSurfaceVariant)
                .frame(maxWidth: .infinity, alignment: .center)
            
            savePickupButton
        }
        .padding(.horizontal, 12)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .background(NeonTheme.surfaceContainer.opacity(0.82))
        .background(.ultraThinMaterial.opacity(0.14))
        .overlay {
            Rectangle()
                .strokeBorder(NeonTheme.secondary.opacity(0.22), lineWidth: 1)
        }
    }
    
    private var savePickupButton: some View {
        Button {
            onSavePickup()
        } label: {
            Group {
                if viewModel.isSavingPickup {
                    ProgressView().tint(NeonTheme.mapSaveAction)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.and.ellipse")
                        Text(L10n.savePickupPoint)
                            .tracking(1)
                    }
                    .foregroundStyle(NeonTheme.mapSaveAction)
                    .shadow(color: NeonTheme.mapSaveAction.opacity(0.55), radius: 8)
                }
            }
            .font(.system(size: 12, weight: .heavy, design: .rounded))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .background(NeonTheme.surfaceContainerHigh.opacity(0.9))
        .overlay {
            Rectangle()
                .strokeBorder(NeonTheme.mapSaveAction.opacity(0.5), lineWidth: 1)
        }
        .disabled(viewModel.isSavingPickup || viewModel.draftPickupCoordinate == nil)
        .opacity(viewModel.draftPickupCoordinate == nil ? 0.45 : 1)
        .buttonStyle(.plain)
    }
    
    // MARK: - Live Badge
    
    private var liveBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(NeonTheme.passengerChrome.statusAccent)
                .frame(width: 8, height: 8)
                .shadow(color: NeonTheme.passengerChrome.statusAccent.opacity(0.8), radius: 4)
            Text(L10n.live)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundStyle(NeonTheme.passengerChrome.statusAccent)
        }
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
