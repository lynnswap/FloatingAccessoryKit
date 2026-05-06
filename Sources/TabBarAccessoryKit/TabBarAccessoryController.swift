import UIKit

@MainActor
@available(iOS 26.0, *)
public final class TabBarAccessoryController {
    public enum Position: Sendable {
        case leading
        case center
        case trailing
    }

    private weak var tabBarController: UITabBarController?
    private let coordinator = TabBarAccessoryCoordinator()

    public init(tabBarController: UITabBarController) {
        self.tabBarController = tabBarController
        TabBarAccessoryViewLifecycleHooks.register(coordinator, for: tabBarController)
    }

    public var isHidden: Bool {
        coordinator.isHidden
    }

    public func setContent(
        _ view: UIView?,
        position: Position = .trailing,
        animated: Bool = false
    ) {
        guard let tabBarController else {
            return
        }

        coordinator.setAccessoryView(
            view,
            position: position,
            animated: animated,
            in: tabBarController
        )
    }

    public func setHidden(
        _ hidden: Bool,
        animated: Bool = false
    ) {
        guard let tabBarController else {
            return
        }

        coordinator.setHidden(
            hidden,
            animated: animated,
            in: tabBarController
        )
    }
}
