import SwiftUI

struct DriverTabBar: View {
    @Bindable var controller: DriverTabBarController

    private let chrome = NeonTheme.driverChrome

    var body: some View {
        RoleTabBarShell(chrome: chrome) {
            HStack {
                ForEach(DriverHomeTab.allCases, id: \.self) { tab in
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
        }
    }

    private func tabForeground(for tab: DriverHomeTab) -> Color {
        guard controller.selectedTab == tab else { return chrome.tabInactive }
        return tab == .map ? chrome.tabMapSelected : chrome.tabSelected
    }

    private func tabShadow(for tab: DriverHomeTab) -> Color {
        guard controller.selectedTab == tab else { return .clear }
        let color = tab == .map ? chrome.tabMapSelected : chrome.tabSelected
        return color.opacity(0.55)
    }
}
