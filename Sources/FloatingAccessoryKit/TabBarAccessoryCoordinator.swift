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

        let isUpdatingCurrentView = contentView === view
        if contentView !== view {
            removeAccessoryView(animated: false, from: tabBarController)
            contentView = view
            tabAccessory = UITabAccessory(contentView: view)
        }
        needsContentSizeMeasurement = true

        self.position = position
        isHidden = false

        if let tabAccessory {
            if isUpdatingCurrentView,
               tabBarController.bottomAccessory === tabAccessory {
                update(in: tabBarController)
            } else {
                tabBarController.setBottomAccessory(tabAccessory, animated: animated)
                update(in: tabBarController)
            }
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
        let measurement = measureContentSize(
            for: contentView,
            maximumWidth: maximumWidth
        )
        contentSizeMeasurement = measurement
        needsContentSizeMeasurement = false
        let initialSize = resolvedSize(
            measurement: measurement,
            maximumWidth: maximumWidth,
            maximumHeight: TabBarAccessoryContainerSizing.availableHeight(for: container)
        )
        let width = contentView.widthAnchor.constraint(equalToConstant: initialSize.width)
        let height = contentView.heightAnchor.constraint(equalToConstant: initialSize.height)
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
            maximumWidth: maximumWidth
        )
        let size = resolvedSize(
            measurement: measurement,
            maximumWidth: maximumWidth,
            maximumHeight: maximumHeight
        )
        update(widthConstraint, to: size.width)
        update(heightConstraint, to: size.height)
        TabBarAccessoryContainerSizing.update(
            container: container,
            contentWidth: size.width,
            position: position
        )
    }

    private func measureContentSizeIfNeeded(
        for view: UIView,
        maximumWidth: CGFloat
    ) -> ContentSizeMeasurement {
        if maximumWidthChanged(to: maximumWidth) {
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
            maximumWidth: maximumWidth
        )
        contentSizeMeasurement = measurement
        needsContentSizeMeasurement = false
        return measurement
    }

    private func measureContentSize(for view: UIView, maximumWidth: CGFloat) -> ContentSizeMeasurement {
        let intrinsicSize = view.intrinsicContentSize
        let fittingSize = view.systemLayoutSizeFitting(
            UIView.layoutFittingCompressedSize,
            withHorizontalFittingPriority: .fittingSizeLevel,
            verticalFittingPriority: .fittingSizeLevel
        )
        let idealSize = view.sizeThatFits(
            UIView.layoutFittingExpandedSize
        )
        let naturalSize = PreferredContentSize(
            width: preferredDimension(fittingSize.width)
                ?? preferredDimension(idealSize.width)
                ?? preferredDimension(intrinsicSize.width),
            height: preferredDimension(fittingSize.height)
                ?? preferredDimension(idealSize.height)
                ?? preferredDimension(intrinsicSize.height)
        )
        let constrainedFit: CGSize?
        if let naturalWidth = naturalSize.width,
           let constrainedWidth = preferredDimension(maximumWidth),
           naturalWidth - constrainedWidth > 0.5 {
            let fittingSize = view.systemLayoutSizeFitting(
                CGSize(
                    width: constrainedWidth,
                    height: UIView.layoutFittingCompressedSize.height
                ),
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel
            )
            if let height = preferredDimension(fittingSize.height) {
                constrainedFit = CGSize(width: constrainedWidth, height: height)
            } else {
                constrainedFit = nil
            }
        } else {
            constrainedFit = nil
        }

        return ContentSizeMeasurement(
            naturalSize: naturalSize,
            constrainedFit: constrainedFit,
            maximumWidth: maximumWidth
        )
    }

    private func maximumWidthChanged(to maximumWidth: CGFloat) -> Bool {
        guard let previousMaximumWidth = contentSizeMeasurement?.maximumWidth else {
            return true
        }

        switch (
            preferredDimension(previousMaximumWidth),
            preferredDimension(maximumWidth)
        ) {
        case let (.some(previous), .some(current)):
            return abs(previous - current) > 0.5
        case (nil, nil):
            return false
        default:
            return true
        }
    }

    private func resolvedSize(
        measurement: ContentSizeMeasurement,
        maximumWidth: CGFloat,
        maximumHeight: CGFloat
    ) -> CGSize {
        let containerHeight = preferredDimension(maximumHeight)
        let preferredHeight = measurement.constrainedFit?.height
            ?? measurement.naturalSize.height
            ?? containerHeight
            ?? 1
        let height = min(preferredHeight, containerHeight ?? preferredHeight)
        let width = measurement.naturalSize.width ?? height

        return CGSize(
            width: cappedWidth(
                max(width, height),
                maximumWidth: maximumWidth
            ),
            height: height
        )
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

    private struct PreferredContentSize {
        let width: CGFloat?
        let height: CGFloat?
    }

    private struct ContentSizeMeasurement {
        let naturalSize: PreferredContentSize
        let constrainedFit: CGSize?
        let maximumWidth: CGFloat
    }
}
