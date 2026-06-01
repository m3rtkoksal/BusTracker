#if os(iOS) || os(visionOS)
import UIKit

enum SharePresenter {
    static func present(items: [Any]) {
        guard !items.isEmpty else { return }
        DispatchQueue.main.async {
            guard let presenter = topPresenterViewController() else { return }

            let activity = UIActivityViewController(activityItems: items, applicationActivities: nil)
            if let popover = activity.popoverPresentationController,
               UIDevice.current.userInterfaceIdiom == .pad {
                popover.sourceView = presenter.view
                popover.sourceRect = CGRect(
                    x: presenter.view.bounds.midX,
                    y: presenter.view.bounds.midY,
                    width: 1,
                    height: 1
                )
                popover.permittedArrowDirections = []
            }

            if let stuck = presenter.presentedViewController as? UIActivityViewController {
                stuck.dismiss(animated: true) {
                    presenter.present(activity, animated: true)
                }
                return
            }
            presenter.present(activity, animated: true)
        }
    }

    private static func topPresenterViewController() -> UIViewController? {
        guard let root = keyWindowRootViewController() else { return nil }
        return topMost(from: root)
    }

    private static func keyWindowRootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    }

    private static func topMost(from controller: UIViewController) -> UIViewController {
        if let presented = controller.presentedViewController,
           !(presented is UIActivityViewController) {
            return topMost(from: presented)
        }
        if let navigation = controller as? UINavigationController,
           let visible = navigation.visibleViewController {
            return topMost(from: visible)
        }
        if let tab = controller as? UITabBarController,
           let selected = tab.selectedViewController {
            return topMost(from: selected)
        }
        return controller
    }
}
#endif
