import UIKit

/// A controller that manages a floating accessory view for a `UITabBarController`.
///
/// Create one controller for each tab bar controller and keep a strong reference
/// to it while the accessory is in use. The controller keeps only a weak
/// reference to the tab bar controller.
///
/// On iOS 26+, FloatingAccessoryKit uses UIKit's native `UITabAccessory`. On
/// iOS 18, it installs a lightweight overlay and keeps it positioned with the
/// tab bar.
@MainActor
public final class TabBarAccessoryController {
    /// The horizontal placement of the accessory.
    public enum Position: Sendable {
        /// Places the accessory near the leading edge of the tab bar area.
        case leading

        /// Centers the accessory above the tab bar area.
        case center

        /// Places the accessory near the trailing edge of the tab bar area.
        case trailing
    }

    private weak var tabBarController: UITabBarController?
    private let coordinator: any TabBarAccessoryCoordinating

    /// Creates an accessory controller for the specified tab bar controller.
    ///
    /// - Parameter tabBarController: The tab bar controller that owns the tab
    ///   bar the accessory should follow.
    public init(tabBarController: UITabBarController) {
        self.tabBarController = tabBarController

        if #available(iOS 26.0, *) {
            coordinator = TabBarAccessoryCoordinator()
        } else {
            coordinator = OverlayTabBarAccessoryCoordinator()
        }

        TabBarAccessoryViewLifecycleHooks.register(coordinator, for: tabBarController)
    }

    /// A Boolean value that indicates whether the installed accessory is hidden.
    ///
    /// When no accessory content is installed, this value is `false`.
    public var isHidden: Bool {
        coordinator.isHidden
    }

    /// Installs, replaces, moves, or removes the accessory content view.
    ///
    /// After changing content in a way that affects its preferred size, call
    /// this method again with the same view. The controller remeasures it and
    /// updates its position without replacing the installed accessory. Passing
    /// `true` for `animated` asks the container to animate that in-place update;
    /// passing `nil` removes the current accessory. On iOS 26+, the native
    /// accessory height is proposed to the content view and its fitting width
    /// determines the platter width, with near-square content snapped to an
    /// exact square. In-place geometry updates honor Reduce Motion on every
    /// supported OS version.
    /// The controller owns the installed view's width and height. Express its
    /// natural size with intrinsic sizing and content-hugging and compression-
    /// resistance priorities; active required constant width or height
    /// constraints violate this contract.
    ///
    /// - Parameters:
    ///   - view: The view to display as the accessory, or `nil` to remove the
    ///     current accessory. The view should provide an intrinsic content size.
    ///     Treat this view as foreground content and do not add your own capsule
    ///     or material background;
    ///     FloatingAccessoryKit uses the native `UITabAccessory` presentation on
    ///     iOS 26+ without adding another background, and adds a matching
    ///     overlay background on iOS 18.
    ///   - position: The horizontal placement for the accessory. The default is
    ///     ``Position/trailing``.
    ///   - animated: Pass `true` to animate the transition.
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

    /// Hides or shows the installed accessory.
    ///
    /// Calling this method before installing content is a no-op.
    ///
    /// - Parameters:
    ///   - hidden: Pass `true` to hide the accessory, or `false` to show it.
    ///   - animated: Pass `true` to animate the visibility change.
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
