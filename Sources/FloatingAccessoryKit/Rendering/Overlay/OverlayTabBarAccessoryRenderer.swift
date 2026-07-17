import UIKit

@MainActor
final class OverlayTabBarAccessoryRenderer: TabBarAccessoryRendering {
    var contentSizeInvalidationHandler: (@MainActor (_ animated: Bool) -> Void)?
    var contentOwnershipRelinquishedHandler: (@MainActor (_ contentView: UIView) -> Void)?

    private enum Metrics {
        static let fallbackLength: CGFloat = 48
        static let horizontalMargin: CGFloat = 8
        static let verticalSpacing: CGFloat = 8
    }

    private var contentHostView: AccessoryContentHostView?
    private var hostView: OverlayAccessoryHostView?
    private var revealHitAreaView: TabBarRevealHitAreaView?
    private var contentConstraints: [NSLayoutConstraint] = []
    private var horizontalConstraint: NSLayoutConstraint?
    private var bottomConstraint: NSLayoutConstraint?
    private var widthConstraint: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?
    private var lastVisibleBottomY: CGFloat?
    private var lastVisibleTabBarHeight: CGFloat?
    private var managedSafeAreaAdjustment: OverlaySafeAreaAdjustment?
    private var transitionGeneration = 0
    private let layoutAnimator: TabBarAccessoryLayoutAnimator

    init(
        isReduceMotionEnabled: @escaping @MainActor () -> Bool = {
            UIAccessibility.isReduceMotionEnabled
        }
    ) {
        layoutAnimator = TabBarAccessoryLayoutAnimator(
            isReduceMotionEnabled: isReduceMotionEnabled
        )
    }

    func invalidateContentSize(animated: Bool) {
        contentHostView?.invalidatePreferredSize(animated: animated)
    }

    func render(
        from previousState: TabBarAccessoryState,
        to state: TabBarAccessoryState,
        animated: Bool,
        in tabBarController: UITabBarController
    ) -> TabBarAccessoryRenderResult {
        let contentChanged = previousState.contentView !== state.contentView
        if contentChanged {
            removeAccessoryPresentation(
                animated: animated,
                from: tabBarController
            )
            if let contentView = state.contentView {
                makePresentation(
                    for: contentView,
                    position: state.position,
                    in: tabBarController
                )
            }
        }

        guard state.contentView != nil else {
            return .applied
        }

        if state.isHidden {
            let result = update(state, in: tabBarController)
            guard result == .applied else {
                return result
            }

            _ = restoreManagedSafeAreaAdjustment()
            _ = removeRevealHitAreaView()
            hideHostView(animated: animated, in: tabBarController)
            return .applied
        }

        let positionChanged = previousState.position.horizontalAlignment
            != state.position.horizontalAlignment
        let result: TabBarAccessoryRenderResult
        if positionChanged && !contentChanged {
            var animatedResult = TabBarAccessoryRenderResult.applied
            layoutAnimator.perform(
                animated: animated,
                in: tabBarController
            ) { _ in
                animatedResult = self.update(state, in: tabBarController)
            }
            result = animatedResult
        } else {
            result = update(state, in: tabBarController)
        }

        guard result == .applied else {
            return result
        }

        if contentChanged || previousState.isHidden {
            showHostView(animated: animated, in: tabBarController)
        }
        return .applied
    }

    func update(
        _ state: TabBarAccessoryState,
        in tabBarController: UITabBarController
    ) -> TabBarAccessoryRenderResult {
        guard let contentView = state.contentView else {
            _ = removeRevealHitAreaView()
            return .applied
        }

        guard let contentHostView,
              contentHostView.contentView === contentView,
              contentView.superview === contentHostView else {
            relinquishPresentationAfterOwnershipLoss()
            FloatingAccessoryDiagnostics.reportOnce(
                id: "overlay-content-ownership-lost",
                "Floating accessory content was reparented without removeContent(); the overlay presentation was detached without modifying the content's new parent."
            )
            return .ownershipLost
        }

        guard !state.isHidden else {
            _ = removeRevealHitAreaView()
            return .applied
        }

        contentHostView.updatePosition(state.position)
        bindContentHostIfNeeded(contentHostView, in: tabBarController)
        hostView?.updateBackground(
            effect: barBackgroundEffect(in: tabBarController),
            color: barBackgroundColor(in: tabBarController)
        )
        let didUpdateSize = updateContentViewSize(
            contentView,
            in: tabBarController
        )
        let didUpdatePosition = updatePosition(
            state.position,
            in: tabBarController
        )
        let didUpdateInsets = updateManagedSafeAreaAdjustment(
            in: tabBarController
        )
        let didUpdateRevealHitArea = updateRevealHitArea(
            in: tabBarController
        )
        if let hostView {
            tabBarController.view.bringSubviewToFront(hostView)
        }
        if didUpdateSize
            || didUpdatePosition
            || didUpdateInsets
            || didUpdateRevealHitArea {
            tabBarController.view.setNeedsLayout()
        }
        return .applied
    }

    private func makePresentation(
        for contentView: UIView,
        position: TabBarAccessoryController.Position,
        in tabBarController: UITabBarController
    ) {
        let contentHostView = AccessoryContentHostView(
            contentView: contentView,
            position: position,
            contentOwnershipRelinquished: { [weak self] contentView in
                self?.contentOwnershipRelinquishedHandler?(contentView)
            }
        ) { [weak self] animated in
            self?.contentSizeInvalidationHandler?(animated)
        }
        self.contentHostView = contentHostView

        let hostView = OverlayAccessoryHostView(
            effect: barBackgroundEffect(in: tabBarController),
            color: barBackgroundColor(in: tabBarController)
        )
        hostView.alpha = 0
        hostView.isHidden = true
        hostView.translatesAutoresizingMaskIntoConstraints = false
        tabBarController.view.addSubview(hostView)
        self.hostView = hostView
        bindContentHostIfNeeded(contentHostView, in: tabBarController)
    }

    private func bindContentHostIfNeeded(
        _ contentHostView: AccessoryContentHostView,
        in tabBarController: UITabBarController
    ) {
        guard let hostView else {
            return
        }

        if hostView.superview !== tabBarController.view {
            tabBarController.view.addSubview(hostView)
        }

        if contentHostView.superview !== hostView {
            NSLayoutConstraint.deactivate(contentConstraints)
            contentHostView.translatesAutoresizingMaskIntoConstraints = false
            hostView.addSubview(contentHostView)
            contentConstraints = [
                contentHostView.topAnchor.constraint(equalTo: hostView.topAnchor),
                contentHostView.leadingAnchor.constraint(equalTo: hostView.leadingAnchor),
                contentHostView.trailingAnchor.constraint(equalTo: hostView.trailingAnchor),
                contentHostView.bottomAnchor.constraint(equalTo: hostView.bottomAnchor)
            ]
            NSLayoutConstraint.activate(contentConstraints)
        }

        installHostConstraintsIfNeeded(hostView, in: tabBarController)
    }

    private func installHostConstraintsIfNeeded(
        _ hostView: UIView,
        in tabBarController: UITabBarController
    ) {
        if widthConstraint == nil {
            widthConstraint = hostView.widthAnchor.constraint(
                equalToConstant: Metrics.fallbackLength
            )
            widthConstraint?.isActive = true
        }

        if heightConstraint == nil {
            heightConstraint = hostView.heightAnchor.constraint(
                equalToConstant: Metrics.fallbackLength
            )
            heightConstraint?.isActive = true
        }

        if bottomConstraint == nil {
            bottomConstraint = hostView.bottomAnchor.constraint(
                equalTo: tabBarController.view.topAnchor
            )
            bottomConstraint?.isActive = true
        }

        if horizontalConstraint == nil {
            horizontalConstraint = hostView.centerXAnchor.constraint(
                equalTo: tabBarController.view.leftAnchor
            )
            horizontalConstraint?.isActive = true
        }
    }

    private func updateContentViewSize(
        _ contentView: UIView,
        in tabBarController: UITabBarController
    ) -> Bool {
        let size = resolvedSize(for: contentView, in: tabBarController)
        let didUpdateWidth = update(widthConstraint, to: size.width)
        let didUpdateHeight = update(heightConstraint, to: size.height)
        return didUpdateWidth || didUpdateHeight
    }

    private func updatePosition(
        _ position: TabBarAccessoryController.Position,
        in tabBarController: UITabBarController
    ) -> Bool {
        let didUpdateBottom = update(
            bottomConstraint,
            to: targetBottomY(in: tabBarController)
        )

        let safeAreaFrame = tabBarController.view.safeAreaLayoutGuide.layoutFrame
        let hostWidth = widthConstraint?.constant ?? Metrics.fallbackLength
        let minimumCenterX = safeAreaFrame.minX
            + Metrics.horizontalMargin
            + hostWidth / 2
        let maximumCenterX = safeAreaFrame.maxX
            - Metrics.horizontalMargin
            - hostWidth / 2
        let alignment = position.resolvedHorizontalAlignment(
            for: tabBarController.view.effectiveUserInterfaceLayoutDirection
        )
        let centerX = minimumCenterX
            + max(maximumCenterX - minimumCenterX, 0) * alignment
        let didUpdateHorizontal = update(horizontalConstraint, to: centerX)
        return didUpdateBottom || didUpdateHorizontal
    }

    private func targetBottomY(
        in tabBarController: UITabBarController
    ) -> CGFloat {
        let view = tabBarController.view!

        if tabBarController.isTabBarHidden {
            return hiddenTargetBottomY(in: tabBarController)
        }

        let tabBarFrame = tabBarController.tabBar.convert(
            tabBarController.tabBar.bounds,
            to: view
        )
        if tabBarController.tabBar.isHidden {
            return hiddenTargetBottomY(in: tabBarController)
        }

        if !tabBarFrame.isEmpty,
           tabBarFrame.intersects(view.bounds),
           tabBarFrame.midY > view.bounds.midY {
            let bottomY = tabBarFrame.minY - Metrics.verticalSpacing
            lastVisibleBottomY = bottomY
            lastVisibleTabBarHeight = tabBarFrame.height
            return bottomY
        }

        if let lastVisibleBottomY {
            return lastVisibleBottomY
        }

        if !tabBarFrame.intersects(view.bounds) {
            return hiddenTargetBottomY(in: tabBarController)
        }

        let tabBarHeight = tabBarController.tabBar.bounds.height
        guard tabBarHeight.isFinite,
              tabBarHeight > 0 else {
            return view.bounds.maxY - Metrics.verticalSpacing
        }

        return view.bounds.maxY - tabBarHeight - Metrics.verticalSpacing
    }

    private func hiddenTargetBottomY(
        in tabBarController: UITabBarController
    ) -> CGFloat {
        let view = tabBarController.view!
        let safeAreaFrame = view.safeAreaLayoutGuide.layoutFrame
        if !safeAreaFrame.isEmpty,
           safeAreaFrame.maxY.isFinite {
            return safeAreaFrame.maxY - Metrics.verticalSpacing
        }

        return view.bounds.maxY - Metrics.verticalSpacing
    }

    private func barBackgroundEffect(
        in tabBarController: UITabBarController
    ) -> UIBlurEffect {
        tabBarController.tabBar.standardAppearance.backgroundEffect
            ?? tabBarController.tabBar.scrollEdgeAppearance?.backgroundEffect
            ?? UIBlurEffect(style: .systemChromeMaterial)
    }

    private func barBackgroundColor(
        in tabBarController: UITabBarController
    ) -> UIColor? {
        tabBarController.tabBar.standardAppearance.backgroundColor
            ?? tabBarController.tabBar.scrollEdgeAppearance?.backgroundColor
    }

    private func resolvedSize(
        for view: UIView,
        in tabBarController: UITabBarController
    ) -> CGSize {
        let intrinsicHeight = preferredDimension(
            view.intrinsicContentSize.height
        )
        let boundsHeight = preferredDimension(view.bounds.height)
        let fallbackHeight = max(
            intrinsicHeight ?? boundsHeight ?? Metrics.fallbackLength,
            Metrics.fallbackLength
        )
        let targetHeight = TabBarAccessoryTabBarButtons.maximumVisibleHeight(
            in: tabBarController.tabBar
        )
            ?? fallbackHeight
        let fittedWidth = TabBarAccessoryContentMeasurement.width(
            for: view,
            proposedHeight: targetHeight,
            policy: .intrinsicAspect
        )

        return CGSize(
            width: min(
                max(fittedWidth, targetHeight),
                maximumWidth(in: tabBarController)
            ),
            height: targetHeight
        )
    }

    private func maximumWidth(
        in tabBarController: UITabBarController
    ) -> CGFloat {
        let safeAreaWidth = tabBarController.view.safeAreaLayoutGuide
            .layoutFrame.width
        let viewWidth = tabBarController.view.bounds.width
        let width = safeAreaWidth.isFinite && safeAreaWidth > 0
            ? safeAreaWidth
            : viewWidth
        let availableWidth = width - Metrics.horizontalMargin * 2
        guard availableWidth.isFinite,
              availableWidth > 0 else {
            return Metrics.fallbackLength
        }

        return max(availableWidth, Metrics.fallbackLength)
    }

    private func updateManagedSafeAreaAdjustment(
        in tabBarController: UITabBarController
    ) -> Bool {
        guard let selectedViewController = tabBarController.selectedViewController
        else {
            return restoreManagedSafeAreaAdjustment()
        }

        let contribution = accessorySafeAreaBottomInset()
        guard contribution > 0 else {
            return restoreManagedSafeAreaAdjustment()
        }

        if managedSafeAreaAdjustment?.viewController !== selectedViewController {
            _ = restoreManagedSafeAreaAdjustment()
            managedSafeAreaAdjustment = OverlaySafeAreaAdjustment(
                viewController: selectedViewController
            )
        }

        return managedSafeAreaAdjustment?.apply(
            contribution: contribution
        ) ?? false
    }

    @discardableResult
    private func restoreManagedSafeAreaAdjustment() -> Bool {
        let didRestore = managedSafeAreaAdjustment?.restore() ?? false
        managedSafeAreaAdjustment = nil
        return didRestore
    }

    private func accessorySafeAreaBottomInset() -> CGFloat {
        let height = heightConstraint?.constant ?? Metrics.fallbackLength
        guard height.isFinite,
              height > 0 else {
            return 0
        }

        return height + Metrics.verticalSpacing
    }

    private func updateRevealHitArea(
        in tabBarController: UITabBarController
    ) -> Bool {
        guard shouldInstallRevealHitArea(in: tabBarController),
              let frame = revealHitAreaFrame(in: tabBarController) else {
            return removeRevealHitAreaView()
        }

        let hitAreaView = revealHitAreaView
            ?? makeRevealHitAreaView(for: tabBarController)
        var didUpdate = false
        if hitAreaView.superview !== tabBarController.view {
            tabBarController.view.addSubview(hitAreaView)
            didUpdate = true
        }
        if hitAreaView.frame != frame {
            hitAreaView.frame = frame
            didUpdate = true
        }
        return didUpdate
    }

    private func shouldInstallRevealHitArea(
        in tabBarController: UITabBarController
    ) -> Bool {
        if tabBarController.isTabBarHidden || tabBarController.tabBar.isHidden {
            return true
        }

        let view = tabBarController.view!
        let tabBarFrame = tabBarController.tabBar.convert(
            tabBarController.tabBar.bounds,
            to: view
        )
        return !tabBarFrame.intersects(view.bounds)
            && lastVisibleBottomY == nil
    }

    private func makeRevealHitAreaView(
        for tabBarController: UITabBarController
    ) -> TabBarRevealHitAreaView {
        let hitAreaView = TabBarRevealHitAreaView(
            tabBarController: tabBarController
        )
        revealHitAreaView = hitAreaView
        return hitAreaView
    }

    private func revealHitAreaFrame(
        in tabBarController: UITabBarController
    ) -> CGRect? {
        let view = tabBarController.view!
        let tabBarHeight = currentTabBarHeight(in: tabBarController)
            ?? lastVisibleTabBarHeight
            ?? 49
        let minY = view.bounds.maxY - tabBarHeight
        let maxY = view.bounds.maxY
        guard minY.isFinite,
              maxY.isFinite,
              minY < maxY else {
            return nil
        }

        return CGRect(
            x: view.bounds.minX,
            y: minY,
            width: view.bounds.width,
            height: maxY - minY
        )
    }

    private func currentTabBarHeight(
        in tabBarController: UITabBarController
    ) -> CGFloat? {
        let tabBarHeight = tabBarController.tabBar.bounds.height
        return tabBarHeight.isFinite && tabBarHeight > 0
            ? tabBarHeight
            : nil
    }

    @discardableResult
    private func removeRevealHitAreaView() -> Bool {
        guard let revealHitAreaView else {
            return false
        }

        revealHitAreaView.removeFromSuperview()
        self.revealHitAreaView = nil
        return true
    }

    private func preferredDimension(_ value: CGFloat) -> CGFloat? {
        guard value != UIView.noIntrinsicMetric,
              value.isFinite,
              value > 0 else {
            return nil
        }

        return value
    }

    private func showHostView(
        animated: Bool,
        in tabBarController: UITabBarController
    ) {
        guard let hostView else {
            return
        }

        let generation = advanceTransitionGeneration()
        let shouldFadeIn = hostView.isHidden || hostView.alpha <= 0.01
        hostView.layer.removeAllAnimations()
        hostView.isHidden = false
        if animated {
            if shouldFadeIn {
                hostView.alpha = 0
            }
            tabBarController.view.setNeedsLayout()
            tabBarController.view.layoutIfNeeded()
            UIView.animate(
                withDuration: 0.25,
                delay: 0,
                options: [.curveEaseInOut]
            ) {
                guard self.transitionGeneration == generation else {
                    return
                }

                hostView.alpha = 1
                tabBarController.view.setNeedsLayout()
                tabBarController.view.layoutIfNeeded()
            }
        } else {
            hostView.alpha = 1
            tabBarController.view.setNeedsLayout()
            tabBarController.view.layoutIfNeeded()
        }
    }

    private func hideHostView(
        animated: Bool,
        in tabBarController: UITabBarController
    ) {
        guard let hostView else {
            return
        }

        let generation = advanceTransitionGeneration()
        hostView.layer.removeAllAnimations()
        let animations = {
            hostView.alpha = 0
            tabBarController.view.setNeedsLayout()
            tabBarController.view.layoutIfNeeded()
        }
        let completion: (Bool) -> Void = { _ in
            guard self.transitionGeneration == generation,
                  self.hostView === hostView else {
                return
            }

            hostView.isHidden = true
        }

        if animated {
            UIView.animate(
                withDuration: 0.25,
                delay: 0,
                options: [.curveEaseInOut],
                animations: animations,
                completion: completion
            )
        } else {
            animations()
            completion(true)
        }
    }

    private func removeAccessoryPresentation(
        animated: Bool,
        from tabBarController: UITabBarController
    ) {
        guard hostView != nil || contentHostView != nil else {
            return
        }

        _ = advanceTransitionGeneration()
        let removedHostView = hostView
        removedHostView?.layer.removeAllAnimations()
        let snapshot = animated
            ? removedHostView?.snapshotView(afterScreenUpdates: false)
            : nil
        let snapshotFrame = removedHostView.map {
            tabBarController.view.convert($0.bounds, from: $0)
        }

        _ = contentHostView?.detachContent(keepingSnapshot: false)
        NSLayoutConstraint.deactivate(contentConstraints)
        contentConstraints.removeAll()
        horizontalConstraint?.isActive = false
        bottomConstraint?.isActive = false
        widthConstraint?.isActive = false
        heightConstraint?.isActive = false
        _ = restoreManagedSafeAreaAdjustment()
        _ = removeRevealHitAreaView()
        removedHostView?.removeFromSuperview()

        horizontalConstraint = nil
        bottomConstraint = nil
        widthConstraint = nil
        heightConstraint = nil
        lastVisibleBottomY = nil
        lastVisibleTabBarHeight = nil
        hostView = nil
        contentHostView = nil

        guard let snapshot,
              let snapshotFrame else {
            return
        }

        snapshot.frame = snapshotFrame
        snapshot.isUserInteractionEnabled = false
        tabBarController.view.addSubview(snapshot)
        UIView.animate(
            withDuration: 0.25,
            delay: 0,
            options: [.curveEaseInOut]
        ) {
            snapshot.alpha = 0
        } completion: { _ in
            snapshot.removeFromSuperview()
        }
    }

    private func relinquishPresentationAfterOwnershipLoss() {
        _ = advanceTransitionGeneration()
        _ = contentHostView?.detachContent(keepingSnapshot: false)
        NSLayoutConstraint.deactivate(contentConstraints)
        contentConstraints.removeAll()
        horizontalConstraint?.isActive = false
        bottomConstraint?.isActive = false
        widthConstraint?.isActive = false
        heightConstraint?.isActive = false
        _ = restoreManagedSafeAreaAdjustment()
        _ = removeRevealHitAreaView()
        hostView?.removeFromSuperview()
        horizontalConstraint = nil
        bottomConstraint = nil
        widthConstraint = nil
        heightConstraint = nil
        lastVisibleBottomY = nil
        lastVisibleTabBarHeight = nil
        hostView = nil
        contentHostView = nil
    }

    private func update(
        _ constraint: NSLayoutConstraint?,
        to constant: CGFloat
    ) -> Bool {
        guard let constraint,
              abs(constraint.constant - constant) > 0.5 else {
            return false
        }

        constraint.constant = constant
        return true
    }

    private func advanceTransitionGeneration() -> Int {
        transitionGeneration += 1
        return transitionGeneration
    }
}
