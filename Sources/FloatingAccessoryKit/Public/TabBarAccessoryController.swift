import UIKit

/// A controller that manages the floating accessory owned by a
/// `UITabBarController`.
///
/// Obtain this controller from
/// ``UIKit/UITabBarController/floatingAccessoryController``. A tab bar
/// controller owns exactly one instance for its lifetime.
///
/// On iOS 26 and later, FloatingAccessoryKit uses UIKit's native
/// `UITabAccessory`. On iOS 18, it installs an overlay that follows the tab
/// bar.
@MainActor
public final class TabBarAccessoryController {
    /// A horizontal placement for a floating accessory.
    ///
    /// Use one of ``leading``, ``center``, or ``trailing``.
    public struct Position: Hashable, Sendable {
        /// Places the accessory near the leading edge of the tab bar area.
        public static let leading = Position(horizontalAlignment: 0)

        /// Centers the accessory above the tab bar area.
        public static let center = Position(horizontalAlignment: 0.5)

        /// Places the accessory near the trailing edge of the tab bar area.
        public static let trailing = Position(horizontalAlignment: 1)

        let horizontalAlignment: CGFloat

        private init(horizontalAlignment: CGFloat) {
            self.horizontalAlignment = horizontalAlignment
        }

        func resolvedHorizontalAlignment(
            for layoutDirection: UIUserInterfaceLayoutDirection
        ) -> CGFloat {
            layoutDirection == .rightToLeft
                ? 1 - horizontalAlignment
                : horizontalAlignment
        }
    }

    private weak var tabBarController: UITabBarController?
    private var state = TabBarAccessoryState()
    private let renderer: any TabBarAccessoryRendering
    private var hostObservation: TabBarAccessoryHostObservation?
    private let layoutAnimator: TabBarAccessoryLayoutAnimator
    private var isRendering = false
    private var pendingRender: PendingRender?
    private var pendingLayoutUpdateAnimated: Bool?

    private struct PendingRender {
        let previousState: TabBarAccessoryState
        var animated: Bool
    }

    init(
        tabBarController: UITabBarController,
        renderer: (any TabBarAccessoryRendering)? = nil,
        isReduceMotionEnabled: @escaping @MainActor () -> Bool = {
            UIAccessibility.isReduceMotionEnabled
        }
    ) {
        self.tabBarController = tabBarController
        layoutAnimator = TabBarAccessoryLayoutAnimator(
            isReduceMotionEnabled: isReduceMotionEnabled
        )

        if let renderer {
            self.renderer = renderer
        } else if #available(iOS 26.0, *) {
            self.renderer = NativeTabBarAccessoryRenderer()
        } else {
            self.renderer = OverlayTabBarAccessoryRenderer()
        }

        self.renderer.contentSizeInvalidationHandler = { [weak self] animated in
            self?.updateLayout(animated: animated)
        }
    }

    /// The currently installed content view, or `nil` when no content is
    /// installed.
    public var contentView: UIView? {
        state.contentView
    }

    /// The requested horizontal placement.
    ///
    /// The initial value is ``Position/trailing``. The value is retained when
    /// content is removed.
    public var position: Position {
        state.position
    }

    /// A Boolean value that indicates whether the accessory is requested to be
    /// hidden.
    ///
    /// The value is retained while content is absent and is applied to the next
    /// installed content view.
    public var isHidden: Bool {
        state.isHidden
    }

    /// Installs or replaces the accessory content view.
    ///
    /// Omitting `position` preserves the current requested placement, which is
    /// initially ``Position/trailing``. This operation preserves
    /// ``isHidden``.
    ///
    /// The content must produce a fitting size through its intrinsic content
    /// size, internal Auto Layout constraints, or nonzero bounds. Layout-driven
    /// size changes are measured automatically. Put explicit changes to
    /// intrinsic size or other fitting-size inputs inside
    /// ``performContentUpdate(animated:_:)``.
    ///
    /// Treat this view as foreground content and do not add your own capsule or
    /// material background. FloatingAccessoryKit uses the native
    /// `UITabAccessory` presentation on iOS 26 and later and adds a matching
    /// overlay background on iOS 18.
    ///
    /// - Parameters:
    ///   - contentView: The view to display as the accessory.
    ///   - position: A new placement, or `nil` to preserve the current one.
    ///   - animated: Pass `true` to animate installation or replacement.
    public func setContentView(
        _ contentView: UIView,
        position: Position? = nil,
        animated: Bool = false
    ) {
        let previousState = state
        state.contentView = contentView
        if let position {
            state.position = position
        }
        render(from: previousState, animated: animated)
    }

    /// Performs changes to accessory content and remeasures it in the same
    /// UIKit update transaction.
    ///
    /// Put every layout-affecting mutation in `updates`. The closure executes
    /// synchronously, including when no content is installed. When content is
    /// installed, its position and visibility remain unchanged.
    ///
    /// - Parameters:
    ///   - animated: Pass `true` to animate the resulting layout change with
    ///     UIKit timing. The default respects Reduce Motion.
    ///   - updates: Changes to the installed content's intrinsic size, bounds,
    ///     constraints, or subview hierarchy.
    public func performContentUpdate(
        animated: Bool = true,
        _ updates: @escaping @MainActor () -> Void
    ) {
        guard let tabBarController,
              state.contentView != nil else {
            updates()
            return
        }

        layoutAnimator.perform(
            animated: animated,
            in: tabBarController
        ) { _ in
            updates()
            self.renderer.invalidateContentSize(animated: false)
        }
    }

    /// Removes the accessory content view.
    ///
    /// The content view is detached before this method returns, even when the
    /// visual removal is animated. This operation preserves ``position`` and
    /// ``isHidden``.
    ///
    /// - Parameter animated: Pass `true` to animate a snapshot of the removed
    ///   presentation when one is available.
    public func removeContent(animated: Bool = false) {
        guard state.contentView != nil else {
            return
        }

        let previousState = state
        state.contentView = nil
        render(from: previousState, animated: animated)
    }

    /// Changes the requested horizontal placement.
    ///
    /// The value is retained while content is absent.
    ///
    /// - Parameters:
    ///   - position: The new placement.
    ///   - animated: Pass `true` to animate installed content to its new
    ///     placement.
    public func setPosition(
        _ position: Position,
        animated: Bool = false
    ) {
        guard state.position.horizontalAlignment != position.horizontalAlignment else {
            return
        }

        let previousState = state
        state.position = position
        guard state.contentView != nil else {
            return
        }
        render(from: previousState, animated: animated)
    }

    /// Changes the requested visibility.
    ///
    /// The value is retained while content is absent.
    ///
    /// - Parameters:
    ///   - hidden: Pass `true` to hide the accessory, or `false` to show it.
    ///   - animated: Pass `true` to animate installed content.
    public func setHidden(
        _ hidden: Bool,
        animated: Bool = false
    ) {
        guard state.isHidden != hidden else {
            return
        }

        let previousState = state
        state.isHidden = hidden
        guard state.contentView != nil else {
            return
        }
        render(from: previousState, animated: animated)
    }

    /// Changes the host tab bar visibility and updates the accessory layout.
    ///
    /// Use this operation instead of calling
    /// `UITabBarController.setTabBarHidden(_:animated:)` directly while an
    /// accessory is installed. UIKit does not expose a visibility-change
    /// notification on iOS 18, so this controller is the coordination boundary
    /// for the tab bar and its accessory.
    ///
    /// - Parameters:
    ///   - hidden: Pass `true` to hide the host tab bar, or `false` to show it.
    ///   - animated: Pass `true` to animate the tab bar visibility change.
    public func setTabBarHidden(
        _ hidden: Bool,
        animated: Bool = false
    ) {
        guard let tabBarController else {
            return
        }

        tabBarController.view.layoutIfNeeded()
        if tabBarController.isTabBarHidden != hidden {
            tabBarController.setTabBarHidden(hidden, animated: animated)
        }
        layoutAnimator.perform(
            animated: animated,
            in: tabBarController
        ) { _ in
            self.updateLayout()
        }
    }

    private func render(from previousState: TabBarAccessoryState, animated: Bool) {
        guard tabBarController != nil else {
            return
        }

        if var pendingRender {
            pendingRender.animated = pendingRender.animated || animated
            self.pendingRender = pendingRender
        } else {
            pendingRender = PendingRender(
                previousState: previousState,
                animated: animated
            )
        }
        drainPendingWork()
    }

    private func updateLayout(animated: Bool = false) {
        guard tabBarController != nil else {
            return
        }

        pendingLayoutUpdateAnimated =
            (pendingLayoutUpdateAnimated ?? false) || animated
        drainPendingWork()
    }

    private func drainPendingWork() {
        guard !isRendering,
              let tabBarController else {
            return
        }

        isRendering = true
        while pendingRender != nil || pendingLayoutUpdateAnimated != nil {
            if let render = pendingRender {
                pendingRender = nil
                let renderedState = state
                let result = renderer.render(
                    from: render.previousState,
                    to: renderedState,
                    animated: render.animated,
                    in: tabBarController
                )
                handle(result, renderedState: renderedState)
            } else if let animated = pendingLayoutUpdateAnimated {
                pendingLayoutUpdateAnimated = nil
                updateRenderer(
                    animated: animated,
                    in: tabBarController
                )
            }
        }
        isRendering = false
        synchronizeHostObservation(in: tabBarController)
    }

    private func updateRenderer(
        animated: Bool,
        in tabBarController: UITabBarController
    ) {
        let renderedState = state
        var result = TabBarAccessoryRenderResult.applied
        if animated {
            layoutAnimator.perform(
                animated: true,
                in: tabBarController
            ) { _ in
                result = self.renderer.update(
                    renderedState,
                    in: tabBarController
                )
            }
        } else {
            result = renderer.update(
                renderedState,
                in: tabBarController
            )
        }
        handle(result, renderedState: renderedState)
    }

    private func handle(
        _ result: TabBarAccessoryRenderResult,
        renderedState: TabBarAccessoryState
    ) {
        if result == .ownershipLost,
           let renderedContentView = renderedState.contentView,
           state.contentView === renderedContentView {
            state.contentView = nil
        }
    }

    private func installHostObservationIfNeeded(
        in tabBarController: UITabBarController
    ) {
        guard hostObservation == nil else {
            return
        }

        let observesOverlayInputs = if #available(iOS 26.0, *) {
            false
        } else {
            true
        }
        hostObservation = TabBarAccessoryHostObservation(
            tabBarController: tabBarController,
            observesOverlayInputs: observesOverlayInputs
        ) { [weak self] in
            self?.updateLayout()
        }
    }

    private func synchronizeHostObservation(
        in tabBarController: UITabBarController
    ) {
        if state.contentView != nil {
            installHostObservationIfNeeded(in: tabBarController)
        } else {
            hostObservation?.invalidate()
            hostObservation = nil
        }
    }
}
