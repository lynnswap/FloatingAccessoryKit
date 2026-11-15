import UIKit

/// Presents accessory content in the column of a vertical tab bar.
///
/// UIKit lays a `UITabAccessory` out along the bottom edge even when the tab
/// bar runs down the side. This renderer owns a glass view instead and places
/// it directly above the tab bar's platter.
@MainActor
@available(iOS 26.0, *)
final class VerticalTabBarAccessoryRenderer: TabBarAccessoryRendering {
    private enum Metrics {
        static let spacingFromTabBar: CGFloat = 8
    }

    var contentSizeInvalidationHandler: (@MainActor (_ animated: Bool) -> Void)?
    var contentOwnershipRelinquishedHandler: (@MainActor (_ contentView: UIView) -> Void)?

    private var glassView: UIVisualEffectView?
    private var contentHostView: AccessoryContentHostView?
    private var platterObservation: TabBarPlatterObservation?
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

    var glassFollowingView: UIView? {
        glassView
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
                id: "vertical-content-ownership-lost",
                "Floating accessory content was reparented without removeContent(); the vertical presentation was detached without modifying the content's new parent."
            )
            return .ownershipLost
        }

        let platterObservation = self.platterObservation
            ?? TabBarPlatterObservation { [weak self] in
                self?.contentSizeInvalidationHandler?(false)
            }
        self.platterObservation = platterObservation
        platterObservation.refresh(in: tabBarController)

        let rootView = tabBarController.view!
        if glassView.superview !== rootView {
            rootView.addSubview(glassView)
        }

        guard let platter = platterObservation.currentPlatter else {
            glassView.isHidden = true
            return .applied
        }

        let platterFrame = platter.convert(platter.bounds, to: rootView)
        let width = platterFrame.width
        let availableHeight = platterFrame.minY
            - Metrics.spacingFromTabBar
            - rootView.safeAreaInsets.top
        let height = min(
            fittingHeight(for: contentView, width: width),
            max(availableHeight, width)
        )
        glassView.isHidden = false
        glassView.frame = CGRect(
            x: platterFrame.midX - width / 2,
            y: platterFrame.minY - Metrics.spacingFromTabBar - height,
            width: width,
            height: height
        )
        glassView.alpha = state.isHidden ? 0 : 1
        glassView.isUserInteractionEnabled = !state.isHidden
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
        contentHostView.traitOverrides.floatingAccessoryAxis = .vertical

        let glassView = UIVisualEffectView(effect: UIGlassEffect(style: .regular))
        glassView.cornerConfiguration = .capsule()
        contentHostView.frame = glassView.contentView.bounds
        contentHostView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        glassView.contentView.addSubview(contentHostView)
        contentHostView.updateTraitsIfNeeded()

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
    }

    private func fittingHeight(
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
