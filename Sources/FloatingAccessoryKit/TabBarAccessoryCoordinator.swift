import UIKit

@MainActor
@available(iOS 26.0, *)
final class TabBarAccessoryCoordinator: TabBarAccessoryCoordinating {
    private var contentView: UIView?
    private var tabAccessory: UITabAccessory?
    private var position: TabBarAccessoryController.Position = .trailing
    private weak var boundContainer: UIView?
    private var boundPosition: TabBarAccessoryController.Position?
    private var installedConstraints: [NSLayoutConstraint] = []
    private var widthConstraint: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?
    private var originalTranslatesAutoresizingMaskIntoConstraints: Bool?
    private var contentSizeMeasurement: ContentSizeMeasurement?
    private var needsContentSizeMeasurement = true
    private let layoutAnimator: TabBarAccessoryLayoutAnimator

    private(set) var isHidden = false

    init(
        isReduceMotionEnabled: @escaping @MainActor () -> Bool = {
            UIAccessibility.isReduceMotionEnabled
        }
    ) {
        layoutAnimator = TabBarAccessoryLayoutAnimator(
            isReduceMotionEnabled: isReduceMotionEnabled
        )
    }

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

        let isUpdatingInstalledAccessory = contentView === view
            && tabBarController.bottomAccessory === tabAccessory
        if contentView !== view {
            removeAccessoryView(animated: false, from: tabBarController)
            contentView = view
            tabAccessory = UITabAccessory(contentView: view)
        }
        needsContentSizeMeasurement = true

        self.position = position
        isHidden = false

        if let tabAccessory {
            if isUpdatingInstalledAccessory {
                updateInstalledAccessory(
                    tabAccessory,
                    animated: animated,
                    in: tabBarController
                )
            } else {
                tabBarController.setBottomAccessory(tabAccessory, animated: animated)
                update(in: tabBarController)
            }
        }
    }

    private func updateInstalledAccessory(
        _ tabAccessory: UITabAccessory,
        animated: Bool,
        in tabBarController: UITabBarController
    ) {
        layoutAnimator.perform(
            animated: animated,
            in: tabBarController
        ) { shouldAnimate in
            tabBarController.setBottomAccessory(
                tabAccessory,
                animated: shouldAnimate
            )
            self.update(in: tabBarController)
        }
    }

    func setHidden(_ hidden: Bool, animated: Bool, in tabBarController: UITabBarController) {
        guard tabAccessory != nil else {
            return
        }

        guard hidden != isHidden else {
            return
        }

        if hidden {
            update(in: tabBarController)
            isHidden = true
            tabBarController.setBottomAccessory(nil, animated: animated)
        } else {
            isHidden = false
            tabBarController.setBottomAccessory(tabAccessory, animated: animated)
            update(in: tabBarController)
        }
    }

    func update(in tabBarController: UITabBarController) {
        guard !isHidden,
              let contentView,
              let container = accessoryContainer(containing: contentView, in: tabBarController) else {
            return
        }

        bindContentViewIfNeeded(contentView, to: container)
        updateContentViewSize(contentView, matching: container)
    }

    private func removeAccessoryView(animated: Bool, from tabBarController: UITabBarController) {
        unbindContentViewConstraints()
        if tabAccessory != nil {
            tabBarController.setBottomAccessory(nil, animated: animated)
        }
        contentView = nil
        tabAccessory = nil
        contentSizeMeasurement = nil
        needsContentSizeMeasurement = true
        isHidden = false
    }

    private func accessoryContainer(containing contentView: UIView, in tabBarController: UITabBarController) -> UIView? {
        guard let container = contentView.superview,
              container.isDescendant(of: tabBarController.view) else {
            return nil
        }

        return container
    }

    private func bindContentViewIfNeeded(_ contentView: UIView, to container: UIView) {
        guard contentView.superview === container else {
            return
        }

        guard boundContainer !== container || boundPosition != position else {
            return
        }

        unbindContentViewConstraints()
        boundContainer = container
        boundPosition = position
        originalTranslatesAutoresizingMaskIntoConstraints = contentView.translatesAutoresizingMaskIntoConstraints
        contentView.translatesAutoresizingMaskIntoConstraints = false
        TabBarAccessoryHitTesting.register(container: container, contentView: contentView)
        TabBarAccessoryContainerSizing.register(
            container: container,
            contentView: contentView,
            position: position
        )

        let maximumWidth = TabBarAccessoryContainerSizing.availableWidth(for: container)
        let maximumHeight = TabBarAccessoryContainerSizing.availableHeight(for: container)
        let measurement = measureContentSize(
            for: contentView,
            maximumWidth: maximumWidth,
            maximumHeight: maximumHeight
        )
        contentSizeMeasurement = measurement
        needsContentSizeMeasurement = false
        let width = contentView.widthAnchor.constraint(equalToConstant: measurement.size.width)
        let height = contentView.heightAnchor.constraint(equalToConstant: measurement.size.height)
        width.identifier = "FloatingAccessoryKit.contentWidth"
        height.identifier = "FloatingAccessoryKit.contentHeight"
        var constraints = [
            width,
            height,
            contentView.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ]

        switch position {
        case .leading:
            constraints.append(contentView.leadingAnchor.constraint(equalTo: container.leadingAnchor))
        case .center:
            constraints.append(contentView.centerXAnchor.constraint(equalTo: container.centerXAnchor))
        case .trailing:
            constraints.append(contentView.trailingAnchor.constraint(equalTo: container.trailingAnchor))
        }

        installedConstraints = constraints
        widthConstraint = width
        heightConstraint = height
        NSLayoutConstraint.activate(installedConstraints)
    }

    private func unbindContentViewConstraints() {
        NSLayoutConstraint.deactivate(installedConstraints)
        installedConstraints.removeAll()
        TabBarAccessoryHitTesting.unregister(container: boundContainer)
        TabBarAccessoryContainerSizing.unregister(container: boundContainer)
        if let contentView, let originalTranslatesAutoresizingMaskIntoConstraints {
            contentView.translatesAutoresizingMaskIntoConstraints = originalTranslatesAutoresizingMaskIntoConstraints
        }
        boundContainer = nil
        boundPosition = nil
        widthConstraint = nil
        heightConstraint = nil
        originalTranslatesAutoresizingMaskIntoConstraints = nil
    }

    private func updateContentViewSize(_ contentView: UIView, matching container: UIView) {
        let maximumWidth = TabBarAccessoryContainerSizing.availableWidth(for: container)
        let maximumHeight = TabBarAccessoryContainerSizing.availableHeight(for: container)
        let measurement = measureContentSizeIfNeeded(
            for: contentView,
            maximumWidth: maximumWidth,
            maximumHeight: maximumHeight
        )
        update(widthConstraint, to: measurement.size.width)
        update(heightConstraint, to: measurement.size.height)
        TabBarAccessoryContainerSizing.update(
            container: container,
            contentWidth: measurement.size.width,
            position: position
        )
    }

    private func measureContentSizeIfNeeded(
        for view: UIView,
        maximumWidth: CGFloat,
        maximumHeight: CGFloat
    ) -> ContentSizeMeasurement {
        if availableSizeChanged(
            maximumWidth: maximumWidth,
            maximumHeight: maximumHeight
        ) {
            needsContentSizeMeasurement = true
        }

        if let contentSizeMeasurement,
           !needsContentSizeMeasurement {
            return contentSizeMeasurement
        }

        let managedSizeConstraints = [widthConstraint, heightConstraint].compactMap { $0 }
        NSLayoutConstraint.deactivate(managedSizeConstraints)
        defer { NSLayoutConstraint.activate(managedSizeConstraints) }

        let measurement = measureContentSize(
            for: view,
            maximumWidth: maximumWidth,
            maximumHeight: maximumHeight
        )
        contentSizeMeasurement = measurement
        needsContentSizeMeasurement = false
        return measurement
    }

    private func measureContentSize(
        for view: UIView,
        maximumWidth: CGFloat,
        maximumHeight: CGFloat
    ) -> ContentSizeMeasurement {
        let height = proposedHeight(for: view, maximumHeight: maximumHeight)
        let fittedWidth = TabBarAccessoryContentMeasurement.width(
            for: view,
            proposedHeight: height,
            policy: .proposedHeight
        )
        let width = max(fittedWidth, height)
        let size = CGSize(
            width: cappedWidth(width, maximumWidth: maximumWidth),
            height: height
        )

        return ContentSizeMeasurement(
            size: size,
            maximumWidth: maximumWidth,
            maximumHeight: maximumHeight
        )
    }

    private func proposedHeight(for view: UIView, maximumHeight: CGFloat) -> CGFloat {
        if let maximumHeight = preferredDimension(maximumHeight) {
            return maximumHeight
        }
        if let intrinsicHeight = preferredDimension(view.intrinsicContentSize.height) {
            return intrinsicHeight
        }
        return 1
    }

    private func availableSizeChanged(
        maximumWidth: CGFloat,
        maximumHeight: CGFloat
    ) -> Bool {
        guard let previous = contentSizeMeasurement else {
            return true
        }
        return dimensionChanged(from: previous.maximumWidth, to: maximumWidth)
            || dimensionChanged(from: previous.maximumHeight, to: maximumHeight)
    }

    private func dimensionChanged(from previous: CGFloat, to current: CGFloat) -> Bool {
        switch (preferredDimension(previous), preferredDimension(current)) {
        case let (.some(previous), .some(current)):
            return abs(previous - current) > 0.5
        case (nil, nil):
            return false
        default:
            return true
        }
    }

    private func cappedWidth(_ width: CGFloat, maximumWidth: CGFloat) -> CGFloat {
        let availableWidth = maximumWidth.isFinite && maximumWidth > 0 ? maximumWidth : width
        return min(max(width, 1), availableWidth)
    }

    private func preferredDimension(_ value: CGFloat) -> CGFloat? {
        guard value != UIView.noIntrinsicMetric,
              value.isFinite,
              value > 0 else {
            return nil
        }

        return value
    }

    private func update(_ constraint: NSLayoutConstraint?, to constant: CGFloat) {
        guard let constraint else {
            return
        }

        guard abs(constraint.constant - constant) > 0.5 else {
            return
        }

        constraint.constant = constant
    }

    private struct ContentSizeMeasurement {
        let size: CGSize
        let maximumWidth: CGFloat
        let maximumHeight: CGFloat
    }
}
