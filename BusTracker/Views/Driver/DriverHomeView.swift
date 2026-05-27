import CoreLocation
import SwiftUI

struct DriverHomeView: BaseView {
    @Environment(ShuttleStore.self) private var store
    @Environment(UserSession.self) private var session
    @Environment(LocationTracker.self) private var locationTracker
    @State var viewModel = DriverHomeViewModel()
    @State var tabBar = DriverTabBarController()
    @State private var showMyServices = false

    private var profile: UserProfile? { session.profile }

    private var passengers: [ShuttleMember] {
        store.members.filter { $0.role == .passenger }
    }

    private var stats: DriverPassengerStats {
        viewModel.passengerStats(from: store.members)
    }

    func content() -> some View {
        VStack(spacing: 0) {
            if tabBar.selectedTab != .map {
                driverTopBar
            }

            Group {
                switch tabBar.selectedTab {
                case .passengers:
                    passengersTab
                case .map:
                    mapTab
                case .settings:
                    settingsTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            DriverTabBar(controller: tabBar)
        }
        .onAppear {
            viewModel.onAppear(store: store, session: session, locationTracker: locationTracker)
        }
        .sheet(isPresented: $showMyServices) {
            MyServicesView()
                .environment(session)
        }
    }

    // MARK: - Top Bar

    private var driverTopBar: some View {
        HStack {
            Image(systemName: "square.grid.2x2")
                .font(.title3)
                .foregroundStyle(NeonTheme.onSurface)
                .onTapGesture {
                    showMyServices = true
                }
            Spacer()
            if store.isTripActive {
                HStack(spacing: 6) {
                    pulseDot
                    Text("AKTİF")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(NeonTheme.secondary)
                }
            }
        }
        .frame(height: 56)
        .padding(.horizontal, 24)
        .background(NeonTheme.background.opacity(0.95))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(NeonTheme.primary.opacity(0.3))
                .frame(height: 1)
                .shadow(color: NeonTheme.primary.opacity(0.1), radius: 6)
        }
    }

    private var pulseDot: some View {
        Circle()
            .fill(NeonTheme.secondary)
            .frame(width: 8, height: 8)
            .shadow(color: NeonTheme.secondary.opacity(0.8), radius: 4)
    }

    // MARK: - Passengers Tab

    private var passengersTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                serviceTitleSection
                serviceCodeCard
                tripControlSection
                statsGrid

                if passengers.isEmpty {
                    emptyPassengersState
                } else {
                    passengerListSection
                }

                if locationTracker.authorizationStatus == .denied || locationTracker.authorizationStatus == .restricted {
                    locationWarning
                } else if store.isTripActive, locationTracker.needsAlwaysAuthorization {
                    backgroundLocationWarning
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
    }

    private var serviceTitleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                pulseDot
                Text("SERVİS ADI")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(NeonTheme.onSurfaceVariant)
            }
            Text((profile?.groupName ?? "Servis").uppercased())
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(NeonTheme.onSurface)
                .tracking(-0.5)
        }
    }

    private var serviceCodeCard: some View {
        VStack(spacing: 16) {
            Text("SERVİS KODU")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(3)
                .foregroundStyle(NeonTheme.primary)
                .shadow(color: NeonTheme.primary.opacity(0.6), radius: 6)

            Text((profile?.groupCode ?? "------").uppercased())
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .tracking(6)
                .foregroundStyle(NeonTheme.onSurface)
                .minimumScaleFactor(0.7)

            HStack(spacing: 8) {
                if let code = profile?.groupCode {
                    ShareLink(item: "ServisTakip servis kodum: \(code)") {
                        codeActionLabel(title: "Paylaş", icon: "square.and.arrow.up", accent: NeonTheme.primary, filled: true)
                    }
                    .buttonStyle(.plain)

                    Button {
                        viewModel.copyGroupCode(code)
                    } label: {
                        codeActionLabel(title: "Kopyala", icon: "doc.on.doc", accent: NeonTheme.onSurfaceVariant, filled: false)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background {
            Rectangle()
                .fill(NeonTheme.surfaceContainer.opacity(0.7))
                .background(.ultraThinMaterial.opacity(0.15))
        }
        .overlay {
            Rectangle()
                .strokeBorder(NeonTheme.primary.opacity(0.2), lineWidth: 1)
        }
        .shadow(color: NeonTheme.primary.opacity(0.15), radius: 12)
    }

    private func codeActionLabel(title: String, icon: String, accent: Color, filled: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.5)
        }
        .foregroundStyle(accent)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background {
            Rectangle()
                .fill(filled ? NeonTheme.primary.opacity(0.1) : NeonTheme.surfaceContainer)
        }
        .overlay {
            Rectangle()
                .strokeBorder(accent.opacity(filled ? 0.4 : 0.3), lineWidth: 1)
        }
    }

    private var statsGrid: some View {
        HStack(spacing: 8) {
            statCard(
                title: "GELECEK",
                value: "\(stats.coming)",
                valueColor: NeonTheme.secondary,
                accentBorder: NeonTheme.secondary.opacity(0.3),
                trailingIcon: "checkmark.circle.fill"
            )
            statCard(
                title: "GELMEYECEK",
                value: "\(stats.notComing)",
                valueColor: Color(hex: 0xFF4444),
                accentBorder: Color(hex: 0xFF4444).opacity(0.3),
                trailingIcon: "xmark.circle.fill"
            )
            statCard(
                title: "BELİRTMEDİ",
                value: "\(stats.unknown)",
                valueColor: Color(hex: 0xFFE04A),
                accentBorder: Color(hex: 0xFFE04A).opacity(0.35),
                trailingIcon: "questionmark.circle.fill"
            )
        }
    }

    private func statCard(
        title: String,
        value: String,
        valueColor: Color,
        accentBorder: Color,
        progress: Double? = nil,
        trailingIcon: String? = nil,
        footnote: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .tracking(0.5)
                .foregroundStyle(NeonTheme.onSurfaceVariant)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(valueColor)
                    .shadow(color: valueColor == NeonTheme.secondary ? NeonTheme.secondary.opacity(0.5) : .clear, radius: 6)
                if let trailingIcon {
                    Image(systemName: trailingIcon)
                        .font(.caption)
                        .foregroundStyle(valueColor.opacity(0.85))
                }
            }

            if let progress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(NeonTheme.surfaceContainerHigh)
                            .frame(height: 2)
                        Rectangle()
                            .fill(NeonTheme.secondary)
                            .frame(width: geo.size.width * progress, height: 2)
                            .shadow(color: NeonTheme.secondary.opacity(0.8), radius: 4)
                    }
                }
                .frame(height: 2)
            } else if let footnote {
                Text(footnote)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(NeonTheme.onSurfaceVariant)
                    .italic()
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NeonTheme.surfaceContainer)
        .overlay {
            Rectangle()
                .strokeBorder(accentBorder, lineWidth: 1)
        }
        .shadow(color: valueColor == NeonTheme.secondary ? NeonTheme.secondary.opacity(0.1) : .clear, radius: 6)
    }

    private var emptyPassengersState: some View {
        VStack(spacing: 20) {
            ZStack {
                Rectangle()
                    .strokeBorder(NeonTheme.primary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                    .frame(width: 80, height: 80)
                Image(systemName: "shareplay.slash")
                    .font(.system(size: 36))
                    .foregroundStyle(NeonTheme.primary.opacity(0.6))
            }

            VStack(spacing: 6) {
                Text("YOLCU BEKLENİYOR")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(NeonTheme.onSurfaceVariant)
                Text("Yolcular yukarıdaki servis kodunu kullanarak katıldığında burada görünecek.")
                    .font(.caption)
                    .foregroundStyle(NeonTheme.outline)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 220)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .opacity(0.85)
    }

    private var passengerListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOLCU LİSTESİ")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .tracking(2)
                .foregroundStyle(NeonTheme.onSurfaceVariant)

            VStack(spacing: 0) {
                ForEach(passengers) { member in
                    HStack(spacing: 12) {
                        Image(systemName: member.attendance.iconName)
                            .font(.title3)
                            .foregroundStyle(attendanceColor(member.attendance))
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(NeonTheme.onSurface)
                            Text(member.attendance.title)
                                .font(.caption)
                                .foregroundStyle(NeonTheme.onSurfaceVariant)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(NeonTheme.surfaceContainer.opacity(0.6))

                    if member.id != passengers.last?.id {
                        Rectangle()
                            .fill(NeonTheme.outline.opacity(0.2))
                            .frame(height: 1)
                    }
                }
            }
            .overlay {
                Rectangle()
                    .strokeBorder(NeonTheme.outline.opacity(0.3), lineWidth: 1)
            }
        }
    }

    private var tripControlSection: some View {
        VStack(spacing: 12) {
            Button {
                Task { await viewModel.toggleTrip(store: store, session: session, locationTracker: locationTracker) }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: store.isTripActive ? "stop.fill" : "bolt.fill")
                        .font(.title3)
                    Text(store.isTripActive ? "SERVİSİ DURDUR" : "SERVİSİ BAŞLAT")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .tracking(2)
                }
                .foregroundStyle(store.isTripActive ? Color(hex: 0xFF4444) : NeonTheme.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(NeonTheme.background)
                .overlay {
                    Rectangle()
                        .strokeBorder(store.isTripActive ? Color(hex: 0xFF4444) : NeonTheme.primary, lineWidth: 2)
                }
                .shadow(color: (store.isTripActive ? Color(hex: 0xFF4444) : NeonTheme.primary).opacity(0.25), radius: 10)
            }
            .buttonStyle(.plain)

            Text(store.isTripActive ? "Konum paylaşılıyor" : "Başlatma hazır")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .tracking(2)
                .foregroundStyle(NeonTheme.outline)
                .frame(maxWidth: .infinity)
        }
        .padding(.top, 4)
    }

    private var locationWarning: some View {
        Text("Konum izni kapalı. Ayarlar'dan izin verin.")
            .font(.caption)
            .foregroundStyle(Color(hex: 0xFF4444))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var backgroundLocationWarning: some View {
        Text("Arka planda konum paylaşımı için Ayarlar'dan \"Her Zaman\" iznini seçin.")
            .font(.caption)
            .foregroundStyle(Color(hex: 0xFFE04A))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Map Tab

    private var mapTab: some View {
        DriverMapTabView(
            driverLocation: store.driverLocation,
            morningPickups: passengerMorningPickups,
            stats: stats,
            isTripActive: store.isTripActive
        )
    }

    private var passengerMorningPickups: [MorningPickup] {
        let passengerIDs = Set(passengers.map(\.id))
        return store.morningPickups.filter { passengerIDs.contains($0.memberID) }
    }

    // MARK: - Settings Tab

    private var settingsTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let code = profile?.groupCode {
                    settingsRow(title: "Servis Kodu", value: code) {
                        viewModel.copyGroupCode(code)
                    }
                }

                if let name = profile?.name {
                    settingsRow(title: "Adınız", value: name, action: nil)
                }

                Button {
                    viewModel.requestSignOut {
                        Task { await viewModel.signOut(store: store, session: session, locationTracker: locationTracker) }
                    }
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Çıkış Yap")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .foregroundStyle(Color(hex: 0xFF4444))
                    .padding(16)
                    .background(NeonTheme.surfaceContainer)
                    .overlay {
                        Rectangle()
                            .strokeBorder(Color(hex: 0xFF4444).opacity(0.3), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(24)
        }
    }

    private func settingsRow(title: String, value: String, action: (() -> Void)?) -> some View {
        Button {
            action?()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title.uppercased())
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(NeonTheme.onSurfaceVariant)
                    Text(value)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(NeonTheme.onSurface)
                }
                Spacer()
                if action != nil {
                    Image(systemName: "doc.on.doc")
                        .foregroundStyle(NeonTheme.secondary)
                }
            }
            .padding(16)
            .background(NeonTheme.surfaceContainer)
            .overlay {
                Rectangle()
                    .strokeBorder(NeonTheme.outline.opacity(0.3), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }

    private func attendanceColor(_ status: AttendanceStatus) -> Color {
        switch status {
        case .coming: NeonTheme.secondary
        case .notComing: Color(hex: 0xFF4444)
        case .unknown: Color(hex: 0xFFE04A)
        }
    }
}

#Preview {
    DriverHomeView()
        .environment(ShuttleStore())
        .environment(UserSession.shared)
        .environment(LocationTracker())
}
