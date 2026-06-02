import SwiftUI

enum NavigationBarStyle {
    case primary
    case auth
    case neonAuth
    case neonDriver
    case neonPassenger
    case driver
    case passenger

    var backgroundColor: Color {
        switch self {
        case .primary, .auth: Color(.systemBackground)
        case .neonAuth, .neonDriver, .neonPassenger: .clear
        case .driver: .blue
        case .passenger: .green
        }
    }

    var titleColor: Color {
        switch self {
        case .driver, .passenger: .white
        case .primary, .auth: .primary
        case .neonAuth, .neonDriver, .neonPassenger: NeonTheme.onSurface
        }
    }

    var usesTransparentBar: Bool {
        switch self {
        case .driver, .passenger: false
        case .primary, .auth, .neonAuth, .neonDriver, .neonPassenger: true
        }
    }

    var usesCustomNavHeader: Bool {
        self == .neonAuth
    }

    var usesNeonBackground: Bool {
        self == .neonAuth || self == .neonDriver || self == .neonPassenger
    }
}

enum NavSubtitleStyle {
    case hidden
    case standard
    case neonCaps
}

enum PopupStyle {
    case error, success, info, warning

    var iconName: String {
        switch self {
        case .error: "xmark.circle.fill"
        case .success: "checkmark.circle.fill"
        case .info: "info.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .error: .red
        case .success: .green
        case .info: .blue
        case .warning: .orange
        }
    }
}

struct PopupPresentation: Identifiable, Equatable {
    let id: UUID
    let style: PopupStyle
    let title: String
    let message: String

    init(style: PopupStyle, title: String, message: String) {
        self.id = UUID()
        self.style = style
        self.title = title
        self.message = message
    }

    static func == (lhs: PopupPresentation, rhs: PopupPresentation) -> Bool {
        lhs.id == rhs.id
    }
}

struct ConfirmPresentation: Identifiable, Equatable {
    let id: UUID
    let title: String
    let message: String
    let confirmTitle: String
    let cancelTitle: String
    let isDestructive: Bool

    init(title: String, message: String, confirmTitle: String, cancelTitle: String, isDestructive: Bool) {
        self.id = UUID()
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.cancelTitle = cancelTitle
        self.isDestructive = isDestructive
    }

    static func == (lhs: ConfirmPresentation, rhs: ConfirmPresentation) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
@Observable
class BaseViewModel {
    var title: String = ""
    var subtitle: String = ""
    var navSubtitleStyle: NavSubtitleStyle = .hidden
    var navigationBarStyle: NavigationBarStyle = .primary
    var showsBackButton: Bool = false
    var usesLargeTitle: Bool = true
    var hidesNavigationBar: Bool = false
    var embedsInNavigationStack: Bool = true

    var isLoading: Bool = false
    var loadingMessage: String = L10n.loading

    var alert: PopupPresentation?
    var toast: PopupPresentation?
    var confirmDialog: ConfirmPresentation?

    private var confirmHandler: (() -> Void)?

    func showError(_ message: String, title: String = L10n.error) {
        alert = PopupPresentation(style: .error, title: title, message: message)
    }

    func showSuccess(_ message: String, title: String = L10n.success) {
        showToast(message, style: .success, title: title)
    }

    func showToast(_ message: String, style: PopupStyle = .success, title: String = "") {
        toast = PopupPresentation(style: style, title: title, message: message)
    }

    func showInfo(_ message: String, title: String = L10n.info) {
        alert = PopupPresentation(style: .info, title: title, message: message)
    }

    func showConfirm(
        title: String,
        message: String,
        confirmTitle: String = L10n.confirm,
        cancelTitle: String = L10n.cancel,
        destructive: Bool = false,
        onConfirm: @escaping () -> Void
    ) {
        confirmDialog = ConfirmPresentation(
            title: title,
            message: message,
            confirmTitle: confirmTitle,
            cancelTitle: cancelTitle,
            isDestructive: destructive
        )
        confirmHandler = onConfirm
    }

    func confirmDialogAction() {
        confirmHandler?()
        clearConfirmDialog()
    }

    func clearConfirmDialog() {
        confirmHandler = nil
        confirmDialog = nil
    }

    func clearAlert() {
        alert = nil
    }

    func clearToast() {
        toast = nil
    }

    func setLoading(_ loading: Bool, message: String = L10n.loading) {
        isLoading = loading
        loadingMessage = message
    }
}
