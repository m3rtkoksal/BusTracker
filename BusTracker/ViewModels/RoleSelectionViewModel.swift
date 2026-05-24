import SwiftUI

@MainActor
@Observable
final class RoleSelectionViewModel: BaseViewModel {
    let onLoginTapped: () -> Void

    init(onLoginTapped: @escaping () -> Void) {
        self.onLoginTapped = onLoginTapped
        super.init()
        title = "Hesap Oluştur"
        subtitle = "Sürücü müsünüz, yolcu mu?"
        navSubtitleStyle = .neonCaps
        usesLargeTitle = false
        hidesNavigationBar = true
        navigationBarStyle = .neonAuth
        embedsInNavigationStack = false
    }
}
