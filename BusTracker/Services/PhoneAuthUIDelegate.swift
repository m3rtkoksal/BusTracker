#if os(iOS) || os(visionOS)
import FirebaseAuth
import UIKit

final class PhoneAuthUIDelegate: NSObject, AuthUIDelegate {
    static let shared = PhoneAuthUIDelegate()

    private override init() {
        super.init()
    }

    func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        guard let presenter = Self.topViewController() else { return }
        presenter.present(viewControllerToPresent, animated: flag, completion: completion)
    }

    func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        guard let presenter = Self.topViewController() else { return }
        presenter.dismiss(animated: flag, completion: completion)
    }

    private static func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let root = base ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController

        if let nav = root as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = root as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(base: selected)
        }
        if let presented = root?.presentedViewController {
            return topViewController(base: presented)
        }
        return root
    }
}
#endif
