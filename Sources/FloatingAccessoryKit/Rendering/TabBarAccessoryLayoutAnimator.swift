import UIKit

@MainActor
struct TabBarAccessoryLayoutAnimator {
    private let isReduceMotionEnabled: @MainActor () -> Bool

    init(
        isReduceMotionEnabled: @escaping @MainActor () -> Bool = {
            UIAccessibility.isReduceMotionEnabled
        }
    ) {
        self.isReduceMotionEnabled = isReduceMotionEnabled
    }

    func perform(
        animated: Bool,
        in tabBarController: UITabBarController,
        updates: @escaping (_ animated: Bool) -> Void
    ) {
        let layoutView = tabBarController.view!
        let reduceMotionEnabled = isReduceMotionEnabled()
        let shouldAnimate = animated
            && UIView.areAnimationsEnabled
            && !reduceMotionEnabled
        guard shouldAnimate else {
            let applyUpdates = {
                updates(false)
                layoutView.layoutIfNeeded()
            }
            if animated && reduceMotionEnabled {
                UIView.performWithoutAnimation(applyUpdates)
            } else {
                applyUpdates()
            }
            return
        }

        layoutView.layoutIfNeeded()
        let inheritedDuration = UIView.inheritedAnimationDuration
        let duration = inheritedDuration > 0
            ? inheritedDuration
            : CATransaction.animationDuration()
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseInOut]
        ) {
            updates(true)
            layoutView.layoutIfNeeded()
        }
    }
}
