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

    accessoryController.removeContent(animated: false)
}
