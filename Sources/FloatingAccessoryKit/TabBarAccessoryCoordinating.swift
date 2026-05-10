import UIKit

@MainActor
protocol TabBarAccessoryCoordinating: AnyObject {
    var isHidden: Bool { get }

    func setAccessoryView(
        _ view: UIView?,
        position: TabBarAccessoryController.Position,
        animated: Bool,
        in tabBarController: UITabBarController
    )

    func setHidden(_ hidden: Bool, animated: Bool, in tabBarController: UITabBarController)

    func update(in tabBarController: UITabBarController)

    func tabBarVisibilityDidChange(
        hidden: Bool,
        animated: Bool,
        in tabBarController: UITabBarController
    )
}

extension TabBarAccessoryCoordinating {
    func tabBarVisibilityDidChange(
        hidden: Bool,
        animated: Bool,
        in tabBarController: UITabBarController
    ) {
        update(in: tabBarController)
    }
}
