import SwiftUI

struct RoleNavBar<Trailing: View>: View {
    let chrome: RoleChrome
    let onMenuTap: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack {
            Image(systemName: "square.grid.2x2")
                .font(.title3)
                .foregroundStyle(NeonTheme.onSurface)
                .onTapGesture(perform: onMenuTap)

            Spacer()

            trailing()
        }
        .frame(height: 56)
        .padding(.horizontal, 24)
        .background(chrome.navBarBackground.opacity(0.97))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(chrome.navBarDivider)
                .frame(height: 1)
                .shadow(color: chrome.navBarDividerShadow, radius: 6)
        }
    }
}

struct RoleTabBarShell<Content: View>: View {
    let chrome: RoleChrome
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, 8)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(chrome.tabBarBackground)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(chrome.tabBarDivider)
                    .frame(height: 1)
                    .shadow(color: chrome.tabBarDividerShadow, radius: 8, y: -2)
            }
    }
}
