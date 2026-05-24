import SwiftUI

struct PassengerTabBar: View {
    @Bindable var controller: PassengerTabBarController

    var body: some View {
        HStack {
            ForEach(PassengerHomeTab.allCases, id: \.self) { tab in
                Button {
                    controller.select(tab)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.title3)
                            .symbolVariant(controller.selectedTab == tab ? .fill : .none)
                        Text(tab.title.uppercased())
                            .font(.system(size: 10, weight: controller.selectedTab == tab ? .bold : .medium, design: .rounded))
                            .tracking(-0.5)
                    }
                    .foregroundStyle(tabForeground(for: tab))
                    .shadow(color: tabShadow(for: tab), radius: 8)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(NeonTheme.surfaceContainerLow)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(NeonTheme.secondary.opacity(0.2))
                .frame(height: 1)
                .shadow(color: NeonTheme.secondary.opacity(0.15), radius: 8, y: -2)
        }
    }

    private func tabForeground(for tab: PassengerHomeTab) -> Color {
        guard controller.selectedTab == tab else { return NeonTheme.outline }
        return tab == .map ? NeonTheme.primary : NeonTheme.secondary
    }

    private func tabShadow(for tab: PassengerHomeTab) -> Color {
        guard controller.selectedTab == tab else { return .clear }
        let color = tab == .map ? NeonTheme.primary : NeonTheme.secondary
        return color.opacity(0.55)
    }
}
