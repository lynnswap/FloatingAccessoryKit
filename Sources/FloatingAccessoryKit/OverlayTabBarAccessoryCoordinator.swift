import UIKit

@MainActor
final class OverlayTabBarAccessoryCoordinator: TabBarAccessoryCoordinating {
    private enum Metrics {
        static let fallbackLength: CGFloat = 48
        static let horizontalMargin: CGFloat = 8
        static let verticalSpacing: CGFloat = 8
    }

    private enum RuntimeClassNames {
        static let legacyTabBarButton = ["Button", "Bar", "Tab", "UI"].reversed().joined()
    }

    private struct ManagedSafeAreaAdjustment {
        weak var viewController: UIViewController?
        var appliedBottomInset: CGFloat
    }

    private var contentView: UIView?
    private var position: TabBarAccessoryController.Position = .trailing
    private var hostView: OverlayAccessoryHostView?
    private var revealHitAreaView: TabBarRevealHitAreaView?
    private var contentConstraints: [NSLayoutConstraint] = []
    private var horizontalConstraint: NSLayoutConstraint?
    private var bottomConstraint: NSLayoutConstraint?
    private var widthConstraint: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?
    private var constrainedPosition: TabBarAccessoryController.Position?
    private var lastVisibleBottomY: CGFloat?
    private var lastVisibleTabBarHeight: CGFloat?
    private var isTabBarHidden = false
    private var originalTranslatesAutoresizingMaskIntoConstraints: Bool?
    private var managedSafeAreaAdjustment: ManagedSafeAreaAdjustment?
    private var transitionGeneration = 0

    private(set) var isHidden = false

    func setAccessoryView(
        _ view: UIView?,
        position: TabBarAccessoryController.Position,
        animated: Bool,
        in tabBarController: UITabBarController
    ) {
        guard let view else {
            removeAccessoryView(animated: animated, from: tabBarController)
            return
        }

        if contentView !== view {
            removeAccessoryView(animated: false, from: tabBarController)
            contentView = view
            originalTranslatesAutoresizingMaskIntoConstraints = view.translatesAutoresizingMaskIntoConstraints
            view.translatesAutoresizingMaskIntoConstraints = false
        }

        self.position = position
        isHidden = false
        bindContentViewIfNeeded(view, in: tabBarController)
        update(in: tabBarController)
        showHostView(animated: animated, in: tabBarController)
    }

    func setHidden(_ hidden: Bool, animated: Bool, in tabBarController: UITabBarController) {
        guard contentView != nil else {
            return
        }

        guard hidden != isHidden else {
            return
        }

        if hidden {
            isHidden = true
            restoreManagedSafeAreaAdjustment()
            removeRevealHitAreaView()
            hideHostView(animated: animated, in: tabBarController)
        } else {
            isHidden = false
            update(in: tabBarController)
            showHostView(animated: animated, in: tabBarController)
        }
    }

    func update(in tabBarController: UITabBarController) {
        guard !isHidden,
              let contentView else {
            removeRevealHitAreaView()
            return
        }

        bindContentViewIfNeeded(contentView, in: tabBarController)
        hostView?.updateBackground(
            effect: barBackgroundEffect(in: tabBarController),
            color: barBackgroundColor(in: tabBarController)
        )
        let didUpdateSize = updateContentViewSize(contentView, in: tabBarController)
        let didUpdatePosition = updatePosition(in: tabBarController)
        let didUpdateInsets = updateManagedSafeAreaAdjustment(in: tabBarController)
        let didUpdateRevealHitArea = updateRevealHitArea(in: tabBarController)
        if let hostView {
            tabBarController.view.bringSubviewToFront(hostView)
        }
        if didUpdateSize || didUpdatePosition || didUpdateInsets || didUpdateRevealHitArea {
            tabBarController.view.setNeedsLayout()
        }
    }

    private func bindContentViewIfNeeded(_ contentView: UIView, in tabBarController: UITabBarController) {
        let hostView = hostView ?? makeHostView(in: tabBarController)
        if hostView.superview !== tabBarController.view {
            tabBarController.view.addSubview(hostView)
        }

        if contentView.superview !== hostView {
            NSLayoutConstraint.deactivate(contentConstraints)
            contentConstraints.removeAll()
            hostView.addSubview(contentView)
            contentConstraints = [
                contentView.topAnchor.constraint(equalTo: hostView.topAnchor),
                contentView.leadingAnchor.constraint(equalTo: hostView.leadingAnchor),
                contentView.trailingAnchor.constraint(equalTo: hostView.trailingAnchor),
                contentView.bottomAnchor.constraint(equalTo: hostView.bottomAnchor)
            ]
            NSLayoutConstraint.activate(contentConstraints)
        }

        installHostConstraintsIfNeeded(hostView, in: tabBarController)
    }

    private func makeHostView(in tabBarController: UITabBarController) -> OverlayAccessoryHostView {
        let hostView = OverlayAccessoryHostView(
            effect: barBackgroundEffect(in: tabBarController),
            color: barBackgroundColor(in: tabBarController)
        )
        hostView.alpha = 0
        hostView.isHidden = true
        hostView.translatesAutoresizingMaskIntoConstraints = false
        tabBarController.view.addSubview(hostView)
        self.hostView = hostView
        return hostView
    }

    private func installHostConstraintsIfNeeded(_ hostView: UIView, in tabBarController: UITabBarController) {
        if widthConstraint == nil {
            widthConstraint = hostView.widthAnchor.constraint(equalToConstant: Metrics.fallbackLength)
            widthConstraint?.isActive = true
        }

        if heightConstraint == nil {
            heightConstraint = hostView.heightAnchor.constraint(equalToConstant: Metrics.fallbackLength)
            heightConstraint?.isActive = true
        }

        if bottomConstraint == nil {
            bottomConstraint = hostView.bottomAnchor.constraint(equalTo: tabBarController.view.topAnchor)
            bottomConstraint?.isActive = true
        }
    }

    private func updateContentViewSize(_ contentView: UIView, in tabBarController: UITabBarController) -> Bool {
        let size = resolvedSize(for: contentView, in: tabBarController)
        let didUpdateWidth = update(widthConstraint, to: size.width)
        let didUpdateHeight = update(heightConstraint, to: size.height)
        return didUpdateWidth || didUpdateHeight
    }

    private func updatePosition(in tabBarController: UITabBarController) -> Bool {
        guard let hostView else {
            return false
        }

        let didUpdateBottom = update(bottomConstraint, to: targetBottomY(in: tabBarController))
        guard horizontalConstraint == nil || constrainedPosition != position else {
            return didUpdateBottom
        }

        horizontalConstraint?.isActive = false
        horizontalConstraint = makeHorizontalConstraint(
            for: hostView,
            position: position,
            in: tabBarController
        )
        constrainedPosition = position
        horizontalConstraint?.isActive = true
        return true
    }

    func tabBarVisibilityDidChange(
        hidden: Bool,
        animated: Bool,
        in tabBarController: UITabBarController
    ) {
        isTabBarHidden = hidden

        guard !isHidden,
              contentView != nil else {
            return
        }

        guard animated else {
            update(in: tabBarController)
            tabBarController.view.layoutIfNeeded()
            return
        }

        tabBarController.view.layoutIfNeeded()
        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseInOut]) {
            self.update(in: tabBarController)
            tabBarController.view.layoutIfNeeded()
        }
    }

    private func makeHorizontalConstraint(
        for hostView: UIView,
        position: TabBarAccessoryController.Position,
        in tabBarController: UITabBarController
    ) -> NSLayoutConstraint {
        let safeArea = tabBarController.view.safeAreaLayoutGuide
        return switch position {
        case .leading:
            hostView.leadingAnchor.constraint(
                equalTo: safeArea.leadingAnchor,
                constant: Metrics.horizontalMargin
            )
        case .center:
            hostView.centerXAnchor.constraint(equalTo: safeArea.centerXAnchor)
        case .trailing:
            hostView.trailingAnchor.constraint(
                equalTo: safeArea.trailingAnchor,
                constant: -Metrics.horizontalMargin
            )
        }
    }

    private func targetBottomY(in tabBarController: UITabBarController) -> CGFloat {
        guard let view = tabBarController.view else {
            return 0
        }

        if isTabBarHidden {
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

    private func hiddenTargetBottomY(in tabBarController: UITabBarController) -> CGFloat {
        guard let view = tabBarController.view else {
            return 0
        }

        let safeAreaFrame = view.safeAreaLayoutGuide.layoutFrame
        if !safeAreaFrame.isEmpty,
           safeAreaFrame.maxY.isFinite {
            return safeAreaFrame.maxY - Metrics.verticalSpacing
        }

        return view.bounds.maxY - Metrics.verticalSpacing
    }

    private func barBackgroundEffect(in tabBarController: UITabBarController) -> UIBlurEffect {
        tabBarController.tabBar.standardAppearance.backgroundEffect
            ?? tabBarController.tabBar.scrollEdgeAppearance?.backgroundEffect
            ?? UIBlurEffect(style: .systemChromeMaterial)
    }

    private func barBackgroundColor(in tabBarController: UITabBarController) -> UIColor? {
        tabBarController.tabBar.standardAppearance.backgroundColor
            ?? tabBarController.tabBar.scrollEdgeAppearance?.backgroundColor
    }

    private func resolvedSize(for view: UIView, in tabBarController: UITabBarController) -> CGSize {
        let fallbackHeight = max(
            preferredDimension(view.intrinsicContentSize.height) ?? Metrics.fallbackLength,
            Metrics.fallbackLength
        )
        let targetHeight = tabBarButtonHeight(in: tabBarController.tabBar)
            ?? fallbackHeight
        let idealSize = view.sizeThatFits(
            CGSize(width: UIView.layoutFittingExpandedSize.width, height: targetHeight)
        )
        let fittingSize = view.systemLayoutSizeFitting(
            CGSize(width: UIView.layoutFittingCompressedSize.width, height: targetHeight),
            withHorizontalFittingPriority: .fittingSizeLevel,
            verticalFittingPriority: .required
        )
        let intrinsicSize = view.intrinsicContentSize

        let width = preferredWidth(forHeight: targetHeight, fittingSize: idealSize)
            ?? preferredWidth(forHeight: targetHeight, fittingSize: fittingSize)
            ?? preferredWidth(forHeight: targetHeight, fittingSize: intrinsicSize)
            ?? targetHeight

        return CGSize(
            width: min(max(width, targetHeight), maximumWidth(in: tabBarController)),
            height: targetHeight
        )
    }

    private func maximumWidth(in tabBarController: UITabBarController) -> CGFloat {
        let safeAreaWidth = tabBarController.view.safeAreaLayoutGuide.layoutFrame.width
        let viewWidth = tabBarController.view.bounds.width
        let width = safeAreaWidth.isFinite && safeAreaWidth > 0 ? safeAreaWidth : viewWidth
        let availableWidth = width - Metrics.horizontalMargin * 2
        guard availableWidth.isFinite,
              availableWidth > 0 else {
            return Metrics.fallbackLength
        }

        return max(availableWidth, Metrics.fallbackLength)
    }

    private func updateManagedSafeAreaAdjustment(in tabBarController: UITabBarController) -> Bool {
        guard let selectedViewController = tabBarController.selectedViewController else {
            return restoreManagedSafeAreaAdjustment()
        }

        let bottomInset = accessorySafeAreaBottomInset()
        guard bottomInset > 0 else {
            return restoreManagedSafeAreaAdjustment()
        }

        if let managedSafeAreaAdjustment,
           managedSafeAreaAdjustment.viewController !== selectedViewController {
            _ = restoreManagedSafeAreaAdjustment()
        }

        let previousAppliedBottomInset = managedSafeAreaAdjustment?.viewController === selectedViewController
            ? managedSafeAreaAdjustment?.appliedBottomInset ?? 0
            : 0
        var insets = selectedViewController.additionalSafeAreaInsets
        if insets.bottom >= previousAppliedBottomInset {
            insets.bottom -= previousAppliedBottomInset
        }
        insets.bottom += bottomInset

        let didUpdate = abs(selectedViewController.additionalSafeAreaInsets.bottom - insets.bottom) > 0.5
        if didUpdate {
            selectedViewController.additionalSafeAreaInsets = insets
        }
        managedSafeAreaAdjustment = ManagedSafeAreaAdjustment(
            viewController: selectedViewController,
            appliedBottomInset: bottomInset
        )
        return didUpdate
    }

    @discardableResult
    private func restoreManagedSafeAreaAdjustment() -> Bool {
        guard let managedSafeAreaAdjustment,
              let viewController = managedSafeAreaAdjustment.viewController else {
            self.managedSafeAreaAdjustment = nil
            return false
        }

        var insets = viewController.additionalSafeAreaInsets
        if insets.bottom >= managedSafeAreaAdjustment.appliedBottomInset {
            insets.bottom -= managedSafeAreaAdjustment.appliedBottomInset
        }
        self.managedSafeAreaAdjustment = nil

        guard abs(viewController.additionalSafeAreaInsets.bottom - insets.bottom) > 0.5 else {
            return false
        }

        viewController.additionalSafeAreaInsets = insets
        return true
    }

    private func accessorySafeAreaBottomInset() -> CGFloat {
        guard !isHidden,
              contentView != nil else {
            return 0
        }

        let height = heightConstraint?.constant ?? Metrics.fallbackLength
        guard height.isFinite,
              height > 0 else {
            return 0
        }

        return height + Metrics.verticalSpacing
    }

    private func updateRevealHitArea(in tabBarController: UITabBarController) -> Bool {
        guard shouldInstallRevealHitArea(in: tabBarController),
              contentView != nil,
              let frame = revealHitAreaFrame(in: tabBarController) else {
            return removeRevealHitAreaView()
        }

        let hitAreaView = revealHitAreaView ?? makeRevealHitAreaView(for: tabBarController)
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

    private func shouldInstallRevealHitArea(in tabBarController: UITabBarController) -> Bool {
        if isTabBarHidden || tabBarController.tabBar.isHidden {
            return true
        }

        guard let view = tabBarController.view else {
            return false
        }

        let tabBarFrame = tabBarController.tabBar.convert(
            tabBarController.tabBar.bounds,
            to: view
        )
        return !tabBarFrame.intersects(view.bounds) && lastVisibleBottomY == nil
    }

    private func makeRevealHitAreaView(for tabBarController: UITabBarController) -> TabBarRevealHitAreaView {
        let hitAreaView = TabBarRevealHitAreaView(tabBarController: tabBarController)
        revealHitAreaView = hitAreaView
        return hitAreaView
    }

    private func revealHitAreaFrame(in tabBarController: UITabBarController) -> CGRect? {
        guard let view = tabBarController.view else {
            return nil
        }

        let tabBarHeight = currentTabBarHeight(in: tabBarController) ?? lastVisibleTabBarHeight ?? 49
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

    private func currentTabBarHeight(in tabBarController: UITabBarController) -> CGFloat? {
        let tabBarHeight = tabBarController.tabBar.bounds.height
        return tabBarHeight.isFinite && tabBarHeight > 0 ? tabBarHeight : nil
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

    private func tabBarButtonHeight(in tabBar: UITabBar) -> CGFloat? {
        tabBar.subviews
            .compactMap { view -> CGFloat? in
                guard isTabBarButton(view),
                      !view.isHidden,
                      view.alpha > 0.01,
                      view.bounds.height.isFinite,
                      view.bounds.height > 0 else {
                    return nil
                }

                return view.bounds.height
            }
            .max()
    }

    private func isTabBarButton(_ view: UIView) -> Bool {
        tabBarButtonClasses().contains { view.isKind(of: $0) }
    }

    private func tabBarButtonClasses() -> [AnyClass] {
        [
            RuntimeClassNames.legacyTabBarButton
        ].compactMap(NSClassFromString)
    }

    private func preferredDimension(_ value: CGFloat) -> CGFloat? {
        guard value != UIView.noIntrinsicMetric,
              value.isFinite,
              value > 0 else {
            return nil
        }

        return value
    }

    private func preferredWidth(forHeight height: CGFloat, fittingSize: CGSize) -> CGFloat? {
        if fittingSize.width.isFinite, fittingSize.width > 0,
           fittingSize.height.isFinite, fittingSize.height > 0 {
            return height * fittingSize.width / fittingSize.height
        }

        if fittingSize.width.isFinite, fittingSize.width > 0 {
            return fittingSize.width
        }

        return nil
    }

    private func showHostView(animated: Bool, in tabBarController: UITabBarController) {
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
            UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseInOut]) {
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

    private func hideHostView(animated: Bool, in tabBarController: UITabBarController) {
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
                  self.hostView === hostView,
                  self.isHidden else {
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

    private func removeAccessoryView(animated: Bool, from tabBarController: UITabBarController) {
        guard let contentView else {
            return
        }

        let generation = advanceTransitionGeneration()
        let removedHostView = hostView
        let removedContentConstraints = contentConstraints
        let removedHorizontalConstraint = horizontalConstraint
        let removedBottomConstraint = bottomConstraint
        let removedWidthConstraint = widthConstraint
        let removedHeightConstraint = heightConstraint
        let removedOriginalTranslatesAutoresizingMaskIntoConstraints = originalTranslatesAutoresizingMaskIntoConstraints
        removedHostView?.layer.removeAllAnimations()

        let cleanup = {
            guard self.transitionGeneration == generation,
                  self.contentView === contentView,
                  self.hostView === removedHostView else {
                return
            }

            NSLayoutConstraint.deactivate(removedContentConstraints)
            self.contentConstraints.removeAll()
            removedHorizontalConstraint?.isActive = false
            removedBottomConstraint?.isActive = false
            removedWidthConstraint?.isActive = false
            removedHeightConstraint?.isActive = false
            self.restoreManagedSafeAreaAdjustment()
            self.removeRevealHitAreaView()
            self.horizontalConstraint = nil
            self.bottomConstraint = nil
            self.widthConstraint = nil
            self.heightConstraint = nil
            self.constrainedPosition = nil
            self.lastVisibleBottomY = nil
            self.lastVisibleTabBarHeight = nil
            if let originalTranslatesAutoresizingMaskIntoConstraints = removedOriginalTranslatesAutoresizingMaskIntoConstraints {
                contentView.translatesAutoresizingMaskIntoConstraints = originalTranslatesAutoresizingMaskIntoConstraints
            }
            contentView.removeFromSuperview()
            removedHostView?.removeFromSuperview()
            self.hostView = nil
            self.contentView = nil
            self.originalTranslatesAutoresizingMaskIntoConstraints = nil
            self.isHidden = false
        }

        guard animated, let hostView else {
            cleanup()
            return
        }

        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseInOut]) {
            guard self.transitionGeneration == generation else {
                return
            }

            hostView.alpha = 0
            tabBarController.view.setNeedsLayout()
            tabBarController.view.layoutIfNeeded()
        } completion: { _ in
            cleanup()
        }
    }

    private func update(_ constraint: NSLayoutConstraint?, to constant: CGFloat) -> Bool {
        guard let constraint else {
            return false
        }

        guard abs(constraint.constant - constant) > 0.5 else {
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

final class TabBarRevealHitAreaView: UIView {
    private weak var tabBarController: UITabBarController?

    init(tabBarController: UITabBarController) {
        self.tabBarController = tabBarController

        super.init(frame: .zero)

        backgroundColor = .clear
        accessibilityIdentifier = "FloatingAccessoryKit.TabBarRevealHitArea"
        isAccessibilityElement = true
        accessibilityLabel = "Show Tab Bar"
        accessibilityTraits = .button

        addGestureRecognizer(UITapGestureRecognizer(
            target: self,
            action: #selector(handleTap(_:))
        ))
        addGestureRecognizer(UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleLongPress(_:))
        ))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func accessibilityActivate() -> Bool {
        revealTabBar()
    }

    @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
        revealTabBar()
    }

    @objc func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else {
            return
        }

        revealTabBar()
    }

    @discardableResult
    func revealTabBar() -> Bool {
        guard let tabBarController else {
            return false
        }

        tabBarController.setTabBarHidden(false, animated: true)
        return true
    }
}

private final class OverlayAccessoryHostView: UIView {
    private let visualEffectView: UIVisualEffectView
    private let backgroundColorView = UIView()

    init(effect: UIBlurEffect, color: UIColor?) {
        visualEffectView = UIVisualEffectView(effect: effect)

        super.init(frame: .zero)

        backgroundColor = .clear
        clipsToBounds = true
        layer.cornerCurve = .continuous

        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.isUserInteractionEnabled = false
        addSubview(visualEffectView)

        backgroundColorView.translatesAutoresizingMaskIntoConstraints = false
        backgroundColorView.isUserInteractionEnabled = false
        backgroundColorView.backgroundColor = color
        addSubview(backgroundColorView)

        NSLayoutConstraint.activate([
            visualEffectView.topAnchor.constraint(equalTo: topAnchor),
            visualEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: bottomAnchor),
            backgroundColorView.topAnchor.constraint(equalTo: topAnchor),
            backgroundColorView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundColorView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundColorView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        layer.cornerRadius = bounds.height / 2
    }

    func updateBackground(effect: UIBlurEffect, color: UIColor?) {
        visualEffectView.effect = effect
        backgroundColorView.backgroundColor = color
    }
}
