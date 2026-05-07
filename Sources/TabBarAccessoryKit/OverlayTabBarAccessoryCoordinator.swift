import UIKit

@MainActor
final class OverlayTabBarAccessoryCoordinator: TabBarAccessoryCoordinating {
    private enum Metrics {
        static let minimumLength: CGFloat = 48
        static let horizontalMargin: CGFloat = 8
        static let verticalSpacing: CGFloat = 8
    }

    private var contentView: UIView?
    private var position: TabBarAccessoryController.Position = .trailing
    private var hostView: OverlayAccessoryHostView?
    private var contentConstraints: [NSLayoutConstraint] = []
    private var horizontalConstraint: NSLayoutConstraint?
    private var bottomConstraint: NSLayoutConstraint?
    private var widthConstraint: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?
    private var constrainedPosition: TabBarAccessoryController.Position?
    private var lastVisibleBottomY: CGFloat?
    private var isTabBarHidden = false
    private var originalTranslatesAutoresizingMaskIntoConstraints: Bool?
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
            update(in: tabBarController)
            isHidden = true
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
            return
        }

        bindContentViewIfNeeded(contentView, in: tabBarController)
        hostView?.updateBackground(
            effect: barBackgroundEffect(in: tabBarController),
            color: barBackgroundColor(in: tabBarController)
        )
        let didUpdateSize = updateContentViewSize(contentView)
        let didUpdatePosition = updatePosition(in: tabBarController)
        if let hostView {
            tabBarController.view.bringSubviewToFront(hostView)
        }
        if didUpdateSize || didUpdatePosition {
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
            widthConstraint = hostView.widthAnchor.constraint(equalToConstant: Metrics.minimumLength)
            widthConstraint?.isActive = true
        }

        if heightConstraint == nil {
            heightConstraint = hostView.heightAnchor.constraint(equalToConstant: Metrics.minimumLength)
            heightConstraint?.isActive = true
        }

        if bottomConstraint == nil {
            bottomConstraint = hostView.bottomAnchor.constraint(equalTo: tabBarController.view.topAnchor)
            bottomConstraint?.isActive = true
        }
    }

    private func updateContentViewSize(_ contentView: UIView) -> Bool {
        let size = resolvedSize(for: contentView)
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
        if !tabBarFrame.isEmpty,
           tabBarFrame.intersects(view.bounds),
           tabBarFrame.midY > view.bounds.midY {
            let bottomY = tabBarFrame.minY - Metrics.verticalSpacing
            lastVisibleBottomY = bottomY
            return bottomY
        }

        if let lastVisibleBottomY {
            return lastVisibleBottomY
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

    private func resolvedSize(for view: UIView) -> CGSize {
        let targetHeight = max(
            preferredDimension(view.intrinsicContentSize.height) ?? Metrics.minimumLength,
            Metrics.minimumLength
        )
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

        return CGSize(width: max(width, targetHeight), height: targetHeight)
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
            self.horizontalConstraint = nil
            self.bottomConstraint = nil
            self.widthConstraint = nil
            self.heightConstraint = nil
            self.constrainedPosition = nil
            self.lastVisibleBottomY = nil
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
