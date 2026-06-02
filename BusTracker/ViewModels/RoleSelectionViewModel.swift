import SwiftUI

@MainActor
@Observable
final class RoleSelectionViewModel: BaseViewModel {
    let onLoginTapped: () -> Void

    init(onLoginTapped: @escaping () -> Void) {
        self.onLoginTapped = onLoginTapped
        super.init()
        title = L10n.roleSelectionTitle
        subtitle = L10n.roleSelectionSubtitle
        navSubtitleStyle = .neonCaps
        usesLargeTitle = false
        hidesNavigationBar = true
        navigationBarStyle = .neonAuth
        embedsInNavigationStack = false
    }
}
