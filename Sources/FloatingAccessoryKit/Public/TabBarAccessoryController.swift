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

    /// A Boolean value that selects the experimental presentation for a
    /// vertical tab bar on iOS 26 and later.
    ///
    /// When `true`, controllers created afterward move the accessory into the
    /// tab bar's column while the tab bar is vertical, and report the layout
    /// direction through ``UIKit/UITraitCollection/floatingAccessoryAxis``. A
    /// horizontal tab bar keeps the `UITabAccessory` presentation. Set this
    /// value before the first access to
    /// ``UIKit/UITabBarController/floatingAccessoryController``.
    public static var followsVerticalTabBar = false

    private weak var tabBarController: UITabBarController?
    private var state = TabBarAccessoryState()
    private let renderer: any TabBarAccessoryRendering
    private var hostObservation: TabBarAccessoryHostObservation?
    private var itemsView: AccessoryItemsView?
    private var requestedItems: RequestedItems?
    private var verticalBarInstallation: SystemBarItemsInstallation?
    private var tabBarBoundsObservation: NSKeyValueObservation?
    private let layoutAnimator: TabBarAccessoryLayoutAnimator
    private var isRendering = false
    private var pendingRender: PendingRender?
    private var pendingLayoutUpdateAnimated: Bool?

    private struct RequestedItems {
        let items: [UIBarButtonItem]
        weak var primaryItem: UIBarButtonItem?
    }

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
            self.renderer = Self.followsVerticalTabBar
                ? AdaptiveTabBarAccessoryRenderer(
                    isReduceMotionEnabled: isReduceMotionEnabled
                )
                : NativeTabBarAccessoryRenderer()
        } else {
            self.renderer = OverlayTabBarAccessoryRenderer()
        }

        self.renderer.contentSizeInvalidationHandler = { [weak self] animated in
            self?.updateLayout(animated: animated)
        }
        self.renderer.contentOwnershipRelinquishedHandler = { [weak self] contentView in
            self?.relinquishContentIfOwned(contentView)
        }
    }

    /// The content view installed with
    /// ``setContentView(_:position:animated:)``, or `nil` when no content view
    /// is installed or the accessory shows ``items``.
    public var contentView: UIView? {
        state.contentView === itemsView ? nil : state.contentView
    }

    /// The items installed with ``setItems(_:position:animated:)``.
    public var items: [UIBarButtonItem] {
        requestedItems?.items ?? []
    }

    isolated deinit {
        // A view controller that outlives the tab bar controller gets its
        // toolbar back.
        verticalBarInstallation?.uninstall(animated: false)
    }

    /// Shows bar button items next to the tab bar.
    ///
    /// Where the items appear follows the tab bar:
    ///
    /// - Along a horizontal tab bar, FloatingAccessoryKit creates a button for
    ///   each item and shows the buttons side by side as the accessory content.
    ///   Passing a different array animates arriving and departing items
    ///   together with the accessory's size.
    /// - Along a vertical tab bar, on iOS 27.1 and later, the items appear in
    ///   the system bar that UIKit lays out in the tab bar's column.
    ///   `primaryItem` takes the prominent style there and the other items
    ///   share one menu; without a primary item, every item appears in the
    ///   bar. An item in the menu appears with its `menuRepresentation`, or
    ///   with its title and image, so give it a title or an image; a system
    ///   item has neither. The items belong to the view controller on top of the selected
    ///   tab's navigation controller, and FloatingAccessoryKit owns that view
    ///   controller's `toolbarItems` while they are shown. The items move when
    ///   the selected tab changes; after a push or a pop, set the items again.
    ///   A selected view controller that is not a navigation controller keeps
    ///   the accessory presentation. Building with Xcode 27.2 or later is
    ///   required; earlier versions keep the accessory presentation.
    ///
    /// As accessory content, each button follows its item's image, title,
    /// primary action or target-action, menu, enabled state, hidden state,
    /// tint color, and accessibility label and identifier. An item without a
    /// tint color uses the label color, as it does in a system bar. An item
    /// with a custom view shows that view. Space items are not supported.
    ///
    /// This operation replaces a content view installed with
    /// ``setContentView(_:position:animated:)``. Passing an empty array removes
    /// the accessory content.
    ///
    /// - Parameters:
    ///   - items: The items to show, in layout order.
    ///   - primaryItem: The item among `items` that stays visible where only
    ///     one item fits.
    ///   - position: A new placement, or `nil` to preserve the current one.
    ///   - animated: Pass `true` to animate the change.
    public func setItems(
        _ items: [UIBarButtonItem],
        primaryItem: UIBarButtonItem? = nil,
        position: Position? = nil,
        animated: Bool = false
    ) {
        if let position {
            setPosition(position, animated: animated)
        }

        guard !items.isEmpty else {
            removeContent(animated: animated)
            return
        }

        requestedItems = RequestedItems(items: items, primaryItem: primaryItem)
        applyRequestedItems(animated: animated)
    }

    /// Shows the requested items in the bar that matches the tab bar's
    /// orientation, the selected tab, and ``isHidden``.
    private func applyRequestedItems(animated: Bool) {
        guard let requestedItems else {
            return
        }

        guard let tabBarController,
              let target = verticalBarTarget(in: tabBarController) else {
            verticalBarInstallation?.uninstall(animated: animated)
            verticalBarInstallation = nil
            let itemsView = self.itemsView ?? makeItemsView()
            self.itemsView = itemsView
            applyItems(requestedItems.items, to: itemsView, animated: animated)
            return
        }

        if let itemsView {
            self.itemsView = nil
            removeInstalledContent(itemsView, animated: false)
            itemsView.setItems([])
        } else if let replacedContentView = state.contentView {
            removeInstalledContent(replacedContentView, animated: animated)
        }
        if verticalBarInstallation?.viewController !== target {
            verticalBarInstallation?.uninstall(animated: false)
            verticalBarInstallation = SystemBarItemsInstallation(
                viewController: target,
                placement: .verticalToolbar
            )
        }
        if state.isHidden {
            verticalBarInstallation?.uninstall(animated: animated)
        } else {
            verticalBarInstallation?.install(
                requestedItems.items,
                primaryItem: requestedItems.primaryItem,
                animated: animated
            )
        }
        synchronizeHostObservation(in: tabBarController)
    }

    /// The view controller whose toolbar UIKit shows next to a vertical tab
    /// bar, or `nil` when the items belong in the accessory.
    private func verticalBarTarget(
        in tabBarController: UITabBarController
    ) -> UIViewController? {
        guard SystemBarItemsInstallation.supportsVerticalToolbar,
              tabBarController.hasVerticalTabBar,
              let navigationController =
                tabBarController.selectedViewController as? UINavigationController else {
            return nil
        }
        return navigationController.topViewController
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
        let replacedItemsView = contentView === itemsView ? nil : itemsView
        if replacedItemsView != nil {
            itemsView = nil
        }
        if contentView !== itemsView {
            requestedItems = nil
            verticalBarInstallation?.uninstall(animated: animated)
            verticalBarInstallation = nil
        }
        let previousState = state
        state.contentView = contentView
        if let position {
            state.position = position
        }
        render(from: previousState, animated: animated)
        replacedItemsView?.setItems([])
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
        performContentUpdate(animated: animated, updates, completion: nil)
    }

    private func performContentUpdate(
        animated: Bool,
        _ updates: @escaping @MainActor () -> Void,
        completion: (@MainActor () -> Void)?
    ) {
        guard let tabBarController,
              state.contentView != nil else {
            updates()
            completion?()
            return
        }

        layoutAnimator.perform(
            animated: animated,
            in: tabBarController,
            updates: { _ in
                updates()
                self.renderer.invalidateContentSize(animated: false)
            },
            completion: completion
        )
    }

    private func makeItemsView() -> AccessoryItemsView {
        let itemsView = AccessoryItemsView()
        itemsView.visibleItemsDidChange = { [weak self, weak itemsView] in
            guard let self,
                  let itemsView,
                  self.itemsView === itemsView else {
                return
            }
            // The tab bar may have turned while no item was visible.
            self.applyRequestedItems(animated: true)
        }
        return itemsView
    }

    private func applyItems(
        _ items: [UIBarButtonItem],
        to itemsView: AccessoryItemsView,
        animated: Bool
    ) {
        guard state.contentView === itemsView else {
            itemsView.setItems(items)
            if itemsView.hasVisibleItems {
                setContentView(itemsView, animated: animated)
            } else if let replacedContentView = state.contentView {
                // The items replace other content even while none is visible.
                removeInstalledContent(replacedContentView, animated: animated)
            }
            return
        }

        let transition = itemsView.prepareTransition(to: items)
        guard itemsView.hasVisibleItems else {
            // Every item is hidden: keep observing the items, but show no
            // accessory until one becomes visible again.
            removeInstalledContent(itemsView, animated: animated)
            transition.updates()
            transition.completion()
            return
        }
        // Items that stay where they are have nothing to animate.
        let animated = animated && transition.changesVisibleItems
        performContentUpdate(
            animated: animated,
            transition.updates,
            completion: transition.completion
        )
        if animated, let glassFollowingView = renderer.glassFollowingView {
            layoutAnimator.performBulge(on: glassFollowingView)
        }
    }

    private func removeInstalledContent(
        _ contentView: UIView,
        animated: Bool
    ) {
        guard state.contentView === contentView else {
            return
        }

        let previousState = state
        state.contentView = nil
        render(from: previousState, animated: animated)
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
        requestedItems = nil
        verticalBarInstallation?.uninstall(animated: animated)
        verticalBarInstallation = nil
        let removedItemsView = itemsView
        itemsView = nil
        // Rendering detaches the presentation first; emptying the items view
        // then returns custom views to their owners' layout mode.
        defer { removedItemsView?.setItems([]) }
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
            if verticalBarInstallation != nil {
                applyRequestedItems(animated: animated)
            }
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

    private func relinquishContentIfOwned(_ contentView: UIView) {
        guard state.contentView === contentView else {
            return
        }

        let previousState = state
        state.contentView = nil
        render(from: previousState, animated: false)
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
            self?.hostDidChange()
        }
    }

    private func hostDidChange() {
        moveRequestedItemsIfNeeded()
        updateLayout()
    }

    /// Moves the items when the tab bar has turned or another tab is selected.
    private func moveRequestedItemsIfNeeded() {
        guard requestedItems != nil, let tabBarController else {
            return
        }
        let target = verticalBarTarget(in: tabBarController)
        if target !== verticalBarInstallation?.viewController {
            applyRequestedItems(animated: false)
        }
    }

    private func synchronizeHostObservation(
        in tabBarController: UITabBarController
    ) {
        if requestedItems != nil, SystemBarItemsInstallation.supportsVerticalToolbar {
            // The tab bar can turn without the root view changing its size.
            if tabBarBoundsObservation == nil {
                // The layer reports every size change, however UIKit sets it.
                tabBarBoundsObservation = tabBarController.tabBar.layer.observe(
                    \.bounds
                ) { [weak self] _, _ in
                    MainActor.assumeIsolated {
                        self?.moveRequestedItemsIfNeeded()
                    }
                }
            }
        } else {
            tabBarBoundsObservation = nil
        }
        if state.contentView != nil || verticalBarInstallation != nil {
            installHostObservationIfNeeded(in: tabBarController)
        } else {
            hostObservation?.invalidate()
            hostObservation = nil
        }
    }
}
