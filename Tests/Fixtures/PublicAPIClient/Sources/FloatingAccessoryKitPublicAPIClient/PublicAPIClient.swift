import FloatingAccessoryKit
import UIKit

@MainActor
public func exerciseFloatingAccessoryPublicAPI(
    in tabBarController: UITabBarController,
    contentView: UIView
) {
    let accessoryController = tabBarController.floatingAccessoryController

    accessoryController.setContentView(
        contentView,
        position: .trailing,
        animated: false
    )
    accessoryController.setPosition(.center, animated: false)
    accessoryController.performContentUpdate(animated: false) {
        contentView.invalidateIntrinsicContentSize()
    }
    accessoryController.setHidden(true, animated: false)
    accessoryController.setHidden(false, animated: false)
    accessoryController.setTabBarHidden(false, animated: false)

    _ = accessoryController.contentView
    _ = accessoryController.position
    _ = accessoryController.isHidden

    let item = UIBarButtonItem(systemItem: .add)
    accessoryController.setItems(
        [item],
        primaryItem: item,
        position: .trailing,
        animated: false
    )
    _ = accessoryController.items

    accessoryController.removeContent(animated: false)

    let viewController = UIViewController()
    viewController.setFloatingAccessoryItems(
        [item],
        primaryItem: item,
        placement: .toolbar,
        animated: false
    )
    _ = viewController.floatingAccessoryItems
    viewController.setFloatingAccessoryItems([])
}
