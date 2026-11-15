import UIKit

/// Chooses the presentation that matches the tab bar's orientation.
///
/// A horizontal tab bar keeps UIKit's `UITabAccessory`, which UIKit moves in
/// step with the tab bar's own transitions. A vertical tab bar switches to
/// ``VerticalTabBarAccessoryRenderer`` so the accessory sits in the tab bar's
/// column instead of along the bottom edge.
@MainActor
@available(iOS 26.0, *)
final class AdaptiveTabBarAccessoryRenderer: TabBarAccessoryRendering {
    var contentSizeInvalidationHandler: (@MainActor (_ animated: Bool) -> Void)? {
        didSet {
            native.contentSizeInvalidationHandler = contentSizeInvalidationHandler
            vertical.contentSizeInvalidationHandler = contentSizeInvalidationHandler
        }
    }

    var contentOwnershipRelinquishedHandler: (@MainActor (_ contentView: UIView) -> Void)? {
        didSet {
            native.contentOwnershipRelinquishedHandler = contentOwnershipRelinquishedHandler
            vertical.contentOwnershipRelinquishedHandler = contentOwnershipRelinquishedHandler
        }
    }

    private let native: NativeTabBarAccessoryRenderer
    private let vertical: VerticalTabBarAccessoryRenderer
    private var usesVertical = false

    init(
        isReduceMotionEnabled: @escaping @MainActor () -> Bool = {
            UIAccessibility.isReduceMotionEnabled
        }
    ) {
        native = NativeTabBarAccessoryRenderer(
            isReduceMotionEnabled: isReduceMotionEnabled
        )
        vertical = VerticalTabBarAccessoryRenderer(
            isReduceMotionEnabled: isReduceMotionEnabled
        )
    }

    private var activeRenderer: any TabBarAccessoryRendering {
        usesVertical ? vertical : native
    }

    func invalidateContentSize(animated: Bool) {
        activeRenderer.invalidateContentSize(animated: animated)
    }

    var glassFollowingView: UIView? {
        activeRenderer.glassFollowingView
    }

    func render(
        from previousState: TabBarAccessoryState,
        to state: TabBarAccessoryState,
        animated: Bool,
        in tabBarController: UITabBarController
    ) -> TabBarAccessoryRenderResult {
        guard Self.hasVerticalTabBar(tabBarController) == usesVertical else {
            return switchRenderer(
                from: previousState,
                to: state,
                in: tabBarController
            )
        }
        return activeRenderer.render(
            from: previousState,
            to: state,
            animated: animated,
            in: tabBarController
        )
    }

    func update(
        _ state: TabBarAccessoryState,
        in tabBarController: UITabBarController
    ) -> TabBarAccessoryRenderResult {
        guard Self.hasVerticalTabBar(tabBarController) == usesVertical else {
            return switchRenderer(
                from: state,
                to: state,
                in: tabBarController
            )
        }
        return activeRenderer.update(state, in: tabBarController)
    }

    private func switchRenderer(
        from previousState: TabBarAccessoryState,
        to state: TabBarAccessoryState,
        in tabBarController: UITabBarController
    ) -> TabBarAccessoryRenderResult {
        var withoutContent = previousState
        withoutContent.contentView = nil
        _ = activeRenderer.render(
            from: previousState,
            to: withoutContent,
            animated: false,
            in: tabBarController
        )

        usesVertical.toggle()

        var beforeInstall = state
        beforeInstall.contentView = nil
        return activeRenderer.render(
            from: beforeInstall,
            to: state,
            animated: false,
            in: tabBarController
        )
    }

    private static func hasVerticalTabBar(
        _ tabBarController: UITabBarController
    ) -> Bool {
        let bounds = tabBarController.tabBar.bounds
        return bounds.height > bounds.width
    }
}
