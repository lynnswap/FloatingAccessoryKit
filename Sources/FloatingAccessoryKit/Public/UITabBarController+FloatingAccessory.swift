import ObjectiveC
import UIKit

@MainActor
private enum FloatingAccessoryAssociationKey {
    static var controller: UInt8 = 0
}

@MainActor
public extension UITabBarController {
    /// The floating-accessory controller owned by this tab bar controller.
    ///
    /// Repeated access returns the same controller for this tab bar controller's
    /// lifetime.
    var floatingAccessoryController: TabBarAccessoryController {
        if let controller = objc_getAssociatedObject(
            self,
            &FloatingAccessoryAssociationKey.controller
        ) as? TabBarAccessoryController {
            return controller
        }

        let controller = TabBarAccessoryController(tabBarController: self)
        objc_setAssociatedObject(
            self,
            &FloatingAccessoryAssociationKey.controller,
            controller,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        return controller
    }
}
