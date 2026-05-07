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
            tabAccessory = UITabAccessory(contentView: view)
        }

        self.position = position
        isHidden = false

        if let tabAccessory {
            tabBarController.setBottomAccessory(tabAccessory, animated: animated)
            update(in: tabBarController)
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

        let width = contentView.widthAnchor.constraint(equalToConstant: contentView.intrinsicContentSize.width)
        let height = contentView.heightAnchor.constraint(equalToConstant: contentView.intrinsicContentSize.height)
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
        let height = container.bounds.height
        guard height.isFinite, height > 0 else {
            return
        }

        update(heightConstraint, to: height)
        let width = resolvedWidth(
            for: contentView,
            height: height,
            maximumWidth: TabBarAccessoryContainerSizing.availableWidth(for: container)
        )
        update(widthConstraint, to: width)
        TabBarAccessoryContainerSizing.update(
            container: container,
            contentWidth: width,
            position: position
        )
    }

    private func resolvedWidth(for view: UIView, height: CGFloat, maximumWidth: CGFloat) -> CGFloat {
        let idealSize = view.sizeThatFits(
            CGSize(width: UIView.layoutFittingExpandedSize.width, height: height)
        )
        let fittingSize = view.systemLayoutSizeFitting(
            CGSize(width: UIView.layoutFittingCompressedSize.width, height: height),
            withHorizontalFittingPriority: .fittingSizeLevel,
            verticalFittingPriority: .required
        )
        let intrinsicSize = view.intrinsicContentSize

        let width = preferredWidth(forHeight: height, fittingSize: idealSize)
            ?? preferredWidth(forHeight: height, fittingSize: fittingSize)
            ?? preferredWidth(forHeight: height, fittingSize: intrinsicSize)
            ?? height

        return cappedWidth(max(width, height), maximumWidth: maximumWidth)
    }

    private func cappedWidth(_ width: CGFloat, maximumWidth: CGFloat) -> CGFloat {
        let availableWidth = maximumWidth.isFinite && maximumWidth > 0 ? maximumWidth : width
        return min(max(width, 1), availableWidth)
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

    private func update(_ constraint: NSLayoutConstraint?, to constant: CGFloat) {
        guard let constraint else {
            return
        }

        guard abs(constraint.constant - constant) > 0.5 else {
            return
        }

        constraint.constant = constant
    }
}
