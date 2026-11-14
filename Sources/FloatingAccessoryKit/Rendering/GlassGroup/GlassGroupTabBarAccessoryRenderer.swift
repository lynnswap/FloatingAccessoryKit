import UIKit

/// Presents accessory content in a glass view that joins the tab bar's glass
/// group.
///
/// UIKit renders the tab bar's glass as one group owned by the view that
/// contains the tab bar. A glass view added beside the tab bar joins that
/// group, so this renderer owns placement itself instead of asking UIKit to
/// lay out a `UITabAccessory`.
@MainActor
@available(iOS 26.0, *)
final class GlassGroupTabBarAccessoryRenderer: TabBarAccessoryRendering {
    private enum Metrics {
        static let accessoryLength: CGFloat = 48
        static let spacingFromTabBar: CGFloat = 8
        static let spacingBesideTabBar: CGFloat = 14
        static let horizontalMarginWithoutTabBar: CGFloat = 21
        static let maximumEdgeMargin: CGFloat = 40
    }

    private struct Placement {
        var host: UIView
        var frame: CGRect
        var bottomSafeAreaContribution: CGFloat
    }

    var contentSizeInvalidationHandler: (@MainActor (_ animated: Bool) -> Void)?
    var contentOwnershipRelinquishedHandler: (@MainActor (_ contentView: UIView) -> Void)?

    private var glassView: UIVisualEffectView?
    private var contentHostView: AccessoryContentHostView?
    private var platterObservation: TabBarPlatterObservation?
    private var safeAreaAdjustment: OverlaySafeAreaAdjustment?
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
            removePresentation(animated: animated)
            if let contentView = state.contentView {
                makePresentation(for: contentView, position: state.position)
            }
        }

        guard state.contentView != nil else {
            return .applied
        }

        guard animated, !contentChanged else {
            return update(state, in: tabBarController)
        }

        var result = TabBarAccessoryRenderResult.applied
        layoutAnimator.perform(
            animated: true,
            in: tabBarController
        ) { _ in
            result = self.update(state, in: tabBarController)
        }
        return result
    }

    func update(
        _ state: TabBarAccessoryState,
        in tabBarController: UITabBarController
    ) -> TabBarAccessoryRenderResult {
        guard let contentView = state.contentView else {
            return .applied
        }

        guard let glassView,
              let contentHostView,
              contentHostView.contentView === contentView,
              contentView.superview === contentHostView else {
            relinquishPresentation()
            FloatingAccessoryDiagnostics.reportOnce(
                id: "glass-group-content-ownership-lost",
                "Floating accessory content was reparented without removeContent(); the glass presentation was detached without modifying the content's new parent."
            )
            return .ownershipLost
        }

        let platterObservation = self.platterObservation
            ?? TabBarPlatterObservation { [weak self] in
                self?.contentSizeInvalidationHandler?(false)
            }
        self.platterObservation = platterObservation
        platterObservation.refresh(in: tabBarController)

        contentHostView.updatePosition(state.position)
        let placement = placement(
            for: contentView,
            in: contentHostView,
            position: state.position,
            platter: platterObservation.currentPlatter,
            tabBarController: tabBarController
        )

        if glassView.superview !== placement.host {
            placement.host.addSubview(glassView)
        }
        glassView.frame = placement.frame
        glassView.alpha = state.isHidden ? 0 : 1
        glassView.isUserInteractionEnabled = !state.isHidden

        applySafeAreaContribution(
            state.isHidden ? 0 : placement.bottomSafeAreaContribution,
            in: tabBarController
        )
        return .applied
    }

    private func makePresentation(
        for contentView: UIView,
        position: TabBarAccessoryController.Position
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

        let glassView = UIVisualEffectView(effect: UIGlassEffect(style: .regular))
        glassView.cornerConfiguration = .capsule()
        contentHostView.frame = glassView.contentView.bounds
        contentHostView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        glassView.contentView.addSubview(contentHostView)

        self.contentHostView = contentHostView
        self.glassView = glassView
    }

    private func removePresentation(animated: Bool) {
        guard let glassView else {
            return
        }

        _ = contentHostView?.detachContent(keepingSnapshot: animated)
        contentHostView = nil
        self.glassView = nil
        platterObservation?.invalidate()
        platterObservation = nil
        safeAreaAdjustment?.restore()
        safeAreaAdjustment = nil

        guard animated, glassView.superview != nil else {
            glassView.removeFromSuperview()
            return
        }

        UIView.animate(
            withDuration: CATransaction.animationDuration(),
            delay: 0,
            options: [.beginFromCurrentState, .curveEaseInOut]
        ) {
            glassView.alpha = 0
        } completion: { _ in
            glassView.removeFromSuperview()
        }
    }

    private func relinquishPresentation() {
        _ = contentHostView?.detachContent(keepingSnapshot: false)
        contentHostView = nil
        glassView?.removeFromSuperview()
        glassView = nil
        platterObservation?.invalidate()
        platterObservation = nil
        safeAreaAdjustment?.restore()
        safeAreaAdjustment = nil
    }

    private func applySafeAreaContribution(
        _ contribution: CGFloat,
        in tabBarController: UITabBarController
    ) {
        let selectedViewController = tabBarController.selectedViewController
        if safeAreaAdjustment?.viewController !== selectedViewController {
            safeAreaAdjustment?.restore()
            safeAreaAdjustment = selectedViewController.map(
                OverlaySafeAreaAdjustment.init(viewController:)
            )
        }
        safeAreaAdjustment?.apply(contribution: contribution)
    }

    // MARK: - Placement

    private func placement(
        for contentView: UIView,
        in contentHostView: AccessoryContentHostView,
        position: TabBarAccessoryController.Position,
        platter: UIView?,
        tabBarController: UITabBarController
    ) -> Placement {
        let rootView = tabBarController.view!
        let tabBar = tabBarController.tabBar
        let isVerticalTabBar = tabBar.bounds.height > tabBar.bounds.width

        guard let platter else {
            setAxis(.horizontal, on: contentHostView)
            return placementWithoutTabBar(
                for: contentView,
                position: position,
                rootView: rootView
            )
        }

        if isVerticalTabBar {
            // The vertical platter is drawn outside the tab bar's glass group,
            // so the accessory stays in the root view where it can receive
            // touches across the whole column.
            setAxis(.vertical, on: contentHostView)
            let platterFrame = platter.convert(platter.bounds, to: rootView)
            let width = platterFrame.width
            let availableHeight = platterFrame.minY
                - Metrics.spacingFromTabBar
                - rootView.safeAreaInsets.top
            let height = min(
                verticalLength(for: contentView, width: width),
                max(availableHeight, width)
            )
            return Placement(
                host: rootView,
                frame: CGRect(
                    x: platterFrame.midX - width / 2,
                    y: platterFrame.minY - Metrics.spacingFromTabBar - height,
                    width: width,
                    height: height
                ),
                bottomSafeAreaContribution: 0
            )
        }

        setAxis(.horizontal, on: contentHostView)
        let host = glassGroupHost(for: tabBar, rootView: rootView)
        let platterFrame = platter.convert(platter.bounds, to: host)
        let hostWidth = host.bounds.width
        let height = Metrics.accessoryLength
        let alignment = position.resolvedHorizontalAlignment(
            for: rootView.effectiveUserInterfaceLayoutDirection
        )

        // The tab bar hugs its items when it has no UITabAccessory, which
        // leaves room beside it. Prefer that room so the accessory shares the
        // tab bar's row, and fall back to the row above when neither side fits.
        let platterMargin = min(platterFrame.minX, hostWidth - platterFrame.maxX)
        let edgeMargin = platterMargin <= Metrics.maximumEdgeMargin
            ? platterMargin
            : Metrics.horizontalMarginWithoutTabBar
        let leftRange = edgeMargin...max(
            edgeMargin,
            platterFrame.minX - Metrics.spacingBesideTabBar
        )
        let rightRange = min(
            platterFrame.maxX + Metrics.spacingBesideTabBar,
            hostWidth - edgeMargin
        )...(hostWidth - edgeMargin)
        let preferredWidth = horizontalLength(
            for: contentView,
            height: height,
            maximumWidth: hostWidth - edgeMargin * 2
        )
        func fits(_ range: ClosedRange<CGFloat>) -> Bool {
            range.upperBound - range.lowerBound >= preferredWidth
        }
        let platterCoversCenter = platterFrame.minX < hostWidth / 2
            && platterFrame.maxX > hostWidth / 2
        let sideRanges: [ClosedRange<CGFloat>]
        if alignment > 0.5 {
            sideRanges = [rightRange, leftRange]
        } else if alignment < 0.5 {
            sideRanges = [leftRange, rightRange]
        } else if platterCoversCenter {
            sideRanges = []
        } else {
            sideRanges = [leftRange, rightRange].sorted {
                $0.upperBound - $0.lowerBound > $1.upperBound - $1.lowerBound
            }
        }

        if let range = sideRanges.first(where: fits) {
            return Placement(
                host: host,
                frame: CGRect(
                    x: range.lowerBound
                        + (range.upperBound - range.lowerBound - preferredWidth) * alignment,
                    y: platterFrame.midY - height / 2,
                    width: preferredWidth,
                    height: height
                ),
                bottomSafeAreaContribution: 0
            )
        }

        let aboveX = platterFrame.minX + (platterFrame.width - preferredWidth) * alignment
        return Placement(
            host: host,
            frame: CGRect(
                x: min(
                    max(aboveX, edgeMargin),
                    max(edgeMargin, hostWidth - edgeMargin - preferredWidth)
                ),
                y: platterFrame.minY - Metrics.spacingFromTabBar - height,
                width: preferredWidth,
                height: height
            ),
            bottomSafeAreaContribution: height + Metrics.spacingFromTabBar
        )
    }

    private func placementWithoutTabBar(
        for contentView: UIView,
        position: TabBarAccessoryController.Position,
        rootView: UIView
    ) -> Placement {
        let height = Metrics.accessoryLength
        let availableWidth = rootView.bounds.width
            - Metrics.horizontalMarginWithoutTabBar * 2
        let width = horizontalLength(
            for: contentView,
            height: height,
            maximumWidth: availableWidth
        )
        let alignment = position.resolvedHorizontalAlignment(
            for: rootView.effectiveUserInterfaceLayoutDirection
        )
        let bottomInset = max(
            rootView.safeAreaInsets.bottom,
            Metrics.spacingFromTabBar
        )
        return Placement(
            host: rootView,
            frame: CGRect(
                x: Metrics.horizontalMarginWithoutTabBar
                    + (availableWidth - width) * alignment,
                y: rootView.bounds.height - bottomInset - height,
                width: width,
                height: height
            ),
            bottomSafeAreaContribution: height + Metrics.spacingFromTabBar
        )
    }

    /// The view whose glass group contains the tab bar.
    ///
    /// UIKit places the tab bar in a container that renders every glass
    /// descendant as one group. Adding the accessory beside the tab bar is what
    /// makes it share the tab bar's material and light/dark adaptation.
    private func glassGroupHost(
        for tabBar: UITabBar,
        rootView: UIView
    ) -> UIView {
        guard let tabBarContainer = tabBar.superview,
              tabBarContainer.isDescendant(of: rootView) else {
            return rootView
        }
        return tabBarContainer
    }

    private func setAxis(
        _ axis: NSLayoutConstraint.Axis,
        on contentHostView: AccessoryContentHostView
    ) {
        guard contentHostView.traitCollection.floatingAccessoryAxis != axis else {
            return
        }
        contentHostView.traitOverrides.floatingAccessoryAxis = axis
        contentHostView.updateTraitsIfNeeded()
    }

    private func horizontalLength(
        for contentView: UIView,
        height: CGFloat,
        maximumWidth: CGFloat
    ) -> CGFloat {
        let fittedWidth = TabBarAccessoryContentMeasurement.width(
            for: contentView,
            proposedHeight: height,
            policy: .proposedHeight
        )
        return min(max(fittedWidth, height), max(maximumWidth, height))
    }

    private func verticalLength(
        for contentView: UIView,
        width: CGFloat
    ) -> CGFloat {
        let fittingSize = contentView.systemLayoutSizeFitting(
            CGSize(
                width: width,
                height: UIView.layoutFittingCompressedSize.height
            ),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        return max(fittingSize.height, width)
    }
}
