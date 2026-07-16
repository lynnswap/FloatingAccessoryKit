import UIKit

@MainActor
@available(iOS 26.0, *)
final class NativeTabBarAccessoryRenderer: TabBarAccessoryRendering {
    var contentSizeInvalidationHandler: (@MainActor (_ animated: Bool) -> Void)?

    private var tabAccessory: UITabAccessory?
    private var contentHostView: AccessoryContentHostView?
    private weak var boundContainer: UIView?
    private var installedConstraints: [NSLayoutConstraint] = []
    private var widthConstraint: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?
    private var originalHostTranslatesAutoresizingMaskIntoConstraints: Bool?
    private var environmentObservation: NativeAccessoryEnvironmentObservation?
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

    func render(
        from previousState: TabBarAccessoryState,
        to state: TabBarAccessoryState,
        animated: Bool,
        in tabBarController: UITabBarController
    ) -> TabBarAccessoryRenderResult {
        let contentChanged = previousState.contentView !== state.contentView
        if contentChanged {
            removeOwnedPresentation(
                animated: animated,
                from: tabBarController
            )
            if let contentView = state.contentView {
                makePresentation(
                    for: contentView,
                    in: tabBarController
                )
            }
        }

        guard let contentView = state.contentView else {
            return .applied
        }

        guard let tabAccessory,
              let contentHostView,
              contentHostView.contentView === contentView,
              contentView.superview === contentHostView else {
            return loseOwnership(
                id: "native-content-ownership-lost",
                message: "Floating accessory content was reparented without removeContent(); the native presentation was detached without modifying the content's new parent.",
                in: tabBarController
            )
        }

        if let installedAccessory = tabBarController.bottomAccessory,
           installedAccessory !== tabAccessory {
            return loseOwnership(
                id: "native-bottom-accessory-ownership-lost",
                message: "UIKit bottomAccessory was replaced while FloatingAccessoryKit content was installed; the package content was detached without modifying the replacement.",
                in: tabBarController
            )
        }

        if state.isHidden {
            if tabBarController.bottomAccessory === tabAccessory {
                tabBarController.setBottomAccessory(nil, animated: animated)
            }
            return .applied
        }

        let needsInstallation = tabBarController.bottomAccessory !== tabAccessory
        if needsInstallation {
            guard contentChanged || previousState.isHidden else {
                return loseOwnership(
                    id: "native-bottom-accessory-ownership-lost",
                    message: "UIKit bottomAccessory was removed while FloatingAccessoryKit content was installed; the package relinquished its detached presentation.",
                    in: tabBarController
                )
            }
            tabBarController.setBottomAccessory(tabAccessory, animated: animated)
        }

        let positionChanged = previousState.position.horizontalAlignment
            != state.position.horizontalAlignment
        if positionChanged && !contentChanged && !needsInstallation {
            var result = TabBarAccessoryRenderResult.applied
            layoutAnimator.perform(
                animated: animated,
                in: tabBarController
            ) { _ in
                result = self.update(state, in: tabBarController)
            }
            return result
        } else {
            return update(state, in: tabBarController)
        }
    }

    func update(
        _ state: TabBarAccessoryState,
        in tabBarController: UITabBarController
    ) -> TabBarAccessoryRenderResult {
        guard let contentView = state.contentView else {
            return .applied
        }

        guard let tabAccessory,
              let contentHostView,
              contentHostView.contentView === contentView else {
            return loseOwnership(
                id: "native-presentation-ownership-lost",
                message: "FloatingAccessoryKit no longer owns a presentation for its recorded content; the stale semantic attachment was cleared.",
                in: tabBarController
            )
        }

        if let installedAccessory = tabBarController.bottomAccessory,
           installedAccessory !== tabAccessory {
            return loseOwnership(
                id: "native-bottom-accessory-ownership-lost",
                message: "UIKit bottomAccessory was replaced while FloatingAccessoryKit content was installed; the package content was detached without modifying the replacement.",
                in: tabBarController
            )
        }

        guard contentView.superview === contentHostView else {
            return loseOwnership(
                id: "native-content-ownership-lost",
                message: "Floating accessory content was reparented without removeContent(); the native presentation was detached without modifying the content's new parent.",
                in: tabBarController
            )
        }

        guard !state.isHidden else {
            return .applied
        }

        guard tabBarController.bottomAccessory === tabAccessory else {
            return loseOwnership(
                id: "native-bottom-accessory-ownership-lost",
                message: "UIKit bottomAccessory was removed while FloatingAccessoryKit content was installed; the package relinquished its detached presentation.",
                in: tabBarController
            )
        }

        guard let container = accessoryContainer(
            containing: contentHostView,
            in: tabBarController
        ) else {
            tabBarController.view.setNeedsLayout()
            return .applied
        }

        bindContentHostIfNeeded(
            contentHostView,
            contentView: contentView,
            to: container,
            position: state.position
        )
        updateContentViewSize(
            contentView,
            position: state.position,
            matching: container
        )
        return .applied
    }

    private func makePresentation(
        for contentView: UIView,
        in tabBarController: UITabBarController
    ) {
        let contentHostView = AccessoryContentHostView(
            contentView: contentView
        ) { [weak self] animated in
            self?.contentSizeInvalidationHandler?(animated)
        }
        self.contentHostView = contentHostView
        tabAccessory = UITabAccessory(contentView: contentHostView)
    }

    private func removeOwnedPresentation(
        animated: Bool,
        from tabBarController: UITabBarController
    ) {
        guard tabAccessory != nil || contentHostView != nil else {
            return
        }

        let ownsBottomAccessory = tabBarController.bottomAccessory === tabAccessory
        let contentHostView = self.contentHostView
        _ = contentHostView?.detachContent(
            keepingSnapshot: animated && ownsBottomAccessory
        )
        unbindContentHostConstraints()

        if ownsBottomAccessory {
            tabBarController.setBottomAccessory(nil, animated: animated)
        }

        tabAccessory = nil
        self.contentHostView = nil
    }

    private func loseOwnership(
        id: String,
        message: String,
        in tabBarController: UITabBarController
    ) -> TabBarAccessoryRenderResult {
        relinquishPresentationAfterOwnershipLoss(in: tabBarController)
        FloatingAccessoryDiagnostics.reportOnce(id: id, message)
        return .ownershipLost
    }

    private func relinquishPresentationAfterOwnershipLoss(
        in tabBarController: UITabBarController
    ) {
        _ = contentHostView?.detachContent(keepingSnapshot: false)
        unbindContentHostConstraints()
        if tabBarController.bottomAccessory === tabAccessory {
            tabBarController.setBottomAccessory(nil, animated: false)
        }
        tabAccessory = nil
        contentHostView = nil
    }

    private func accessoryContainer(
        containing contentHostView: UIView,
        in tabBarController: UITabBarController
    ) -> UIView? {
        guard let container = contentHostView.superview,
              container.isDescendant(of: tabBarController.view) else {
            return nil
        }

        return container
    }

    private func bindContentHostIfNeeded(
        _ contentHostView: AccessoryContentHostView,
        contentView: UIView,
        to container: UIView,
        position: TabBarAccessoryController.Position
    ) {
        guard contentHostView.superview === container else {
            return
        }

        if boundContainer !== container {
            unbindContentHostConstraints()
            boundContainer = container
            originalHostTranslatesAutoresizingMaskIntoConstraints =
                contentHostView.translatesAutoresizingMaskIntoConstraints
            contentHostView.translatesAutoresizingMaskIntoConstraints = false
            NativeAccessoryHitTesting.register(
                container: container,
                contentView: contentView
            )
            NativeAccessoryContainerLayout.register(
                container: container,
                contentView: contentHostView,
                position: position
            )
            environmentObservation = NativeAccessoryEnvironmentObservation(
                container: container,
                contentHostView: contentHostView
            ) { [weak self] in
                self?.contentSizeInvalidationHandler?(false)
            }

            let maximumWidth = NativeAccessoryContainerLayout.availableWidth(
                for: container
            )
            let maximumHeight = NativeAccessoryContainerLayout.availableHeight(
                for: container
            )
            let size = measureContentSize(
                for: contentView,
                maximumWidth: maximumWidth,
                maximumHeight: maximumHeight
            )

            let width = contentHostView.widthAnchor.constraint(
                equalToConstant: size.width
            )
            let height = contentHostView.heightAnchor.constraint(
                equalToConstant: size.height
            )
            width.identifier = "FloatingAccessoryKit.contentWidth"
            height.identifier = "FloatingAccessoryKit.contentHeight"
            installedConstraints = [
                width,
                height,
                contentHostView.centerXAnchor.constraint(
                    equalTo: container.centerXAnchor
                ),
                contentHostView.centerYAnchor.constraint(
                    equalTo: container.centerYAnchor
                )
            ]
            widthConstraint = width
            heightConstraint = height
            NSLayoutConstraint.activate(installedConstraints)
        }

        NativeAccessoryContainerLayout.update(
            container: container,
            contentWidth: widthConstraint?.constant ?? 0,
            position: position
        )
    }

    private func unbindContentHostConstraints() {
        environmentObservation?.invalidate()
        environmentObservation = nil
        NSLayoutConstraint.deactivate(installedConstraints)
        installedConstraints.removeAll()
        NativeAccessoryHitTesting.unregister(container: boundContainer)
        NativeAccessoryContainerLayout.unregister(container: boundContainer)
        if let contentHostView,
           let originalHostTranslatesAutoresizingMaskIntoConstraints {
            contentHostView.translatesAutoresizingMaskIntoConstraints =
                originalHostTranslatesAutoresizingMaskIntoConstraints
        }
        boundContainer = nil
        widthConstraint = nil
        heightConstraint = nil
        originalHostTranslatesAutoresizingMaskIntoConstraints = nil
    }

    private func updateContentViewSize(
        _ contentView: UIView,
        position: TabBarAccessoryController.Position,
        matching container: UIView
    ) {
        let maximumWidth = NativeAccessoryContainerLayout.availableWidth(
            for: container
        )
        let maximumHeight = NativeAccessoryContainerLayout.availableHeight(
            for: container
        )
        let size = measureContentSize(
            for: contentView,
            maximumWidth: maximumWidth,
            maximumHeight: maximumHeight
        )
        update(widthConstraint, to: size.width)
        update(heightConstraint, to: size.height)
        NativeAccessoryContainerLayout.update(
            container: container,
            contentWidth: size.width,
            position: position
        )
    }

    private func measureContentSize(
        for view: UIView,
        maximumWidth: CGFloat,
        maximumHeight: CGFloat
    ) -> CGSize {
        let managedSizeConstraints = [widthConstraint, heightConstraint]
            .compactMap { $0 }
        NSLayoutConstraint.deactivate(managedSizeConstraints)
        defer { NSLayoutConstraint.activate(managedSizeConstraints) }

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

        return size
    }

    private func proposedHeight(
        for view: UIView,
        maximumHeight: CGFloat
    ) -> CGFloat {
        if let maximumHeight = preferredDimension(maximumHeight) {
            return maximumHeight
        }
        if let intrinsicHeight = preferredDimension(
            view.intrinsicContentSize.height
        ) {
            return intrinsicHeight
        }
        if let boundsHeight = preferredDimension(view.bounds.height) {
            return boundsHeight
        }
        return 1
    }

    private func cappedWidth(
        _ width: CGFloat,
        maximumWidth: CGFloat
    ) -> CGFloat {
        let availableWidth = maximumWidth.isFinite && maximumWidth > 0
            ? maximumWidth
            : width
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

    private func update(
        _ constraint: NSLayoutConstraint?,
        to constant: CGFloat
    ) {
        guard let constraint,
              abs(constraint.constant - constant) > 0.5 else {
            return
        }

        constraint.constant = constant
    }

}
