import UIKit

@MainActor
struct TabBarAccessoryState {
    var contentView: UIView?
    var position: TabBarAccessoryController.Position = .trailing
    var isHidden = false
}

enum TabBarAccessoryRenderResult {
    case applied
    case ownershipLost
}

@MainActor
protocol TabBarAccessoryRendering: AnyObject {
    var contentSizeInvalidationHandler: (@MainActor (_ animated: Bool) -> Void)? { get set }
    var contentOwnershipRelinquishedHandler: (@MainActor (_ contentView: UIView) -> Void)? { get set }

    func invalidateContentSize(animated: Bool)

    func render(
        from previousState: TabBarAccessoryState,
        to state: TabBarAccessoryState,
        animated: Bool,
        in tabBarController: UITabBarController
    ) -> TabBarAccessoryRenderResult

    func update(
        _ state: TabBarAccessoryState,
        in tabBarController: UITabBarController
    ) -> TabBarAccessoryRenderResult
}
