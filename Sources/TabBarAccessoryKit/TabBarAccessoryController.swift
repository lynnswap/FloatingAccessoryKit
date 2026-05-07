import UIKit

@MainActor
public final class TabBarAccessoryController {
    public enum Position: Sendable {
        case leading
        case center
        case trailing
    }

    private weak var tabBarController: UITabBarController?
    private let coordinator: any TabBarAccessoryCoordinating

    public init(tabBarController: UITabBarController) {
        self.tabBarController = tabBarController

        if #available(iOS 26.0, *) {
            coordinator = TabBarAccessoryCoordinator()
        } else {
            coordinator = OverlayTabBarAccessoryCoordinator()
        }

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
