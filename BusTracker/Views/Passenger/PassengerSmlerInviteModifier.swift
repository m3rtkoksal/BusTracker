import SwiftUI

struct PassengerSmlerInviteModifier: ViewModifier {
    @Environment(SmlerInviteCoordinator.self) private var smlerInviteCoordinator
    @Binding var settingsPath: NavigationPath
    let tabBar: PassengerTabBarController
    let onAppearCheck: () -> Void

    func body(content: Content) -> some View {
        content
            .onAppear(perform: onAppearCheck)
            .onChange(of: smlerInviteCoordinator.pendingAddServiceCode) { _, code in
                guard let code else { return }
                tabBar.select(.settings)
                settingsPath.append(
                    MyServicesRoute(initialServiceCode: code, openAddServiceOnAppear: true)
                )
                smlerInviteCoordinator.clearAddServicePending()
            }
    }
}
