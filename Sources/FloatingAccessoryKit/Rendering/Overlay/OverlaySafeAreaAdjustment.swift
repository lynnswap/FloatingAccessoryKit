import UIKit

@MainActor
final class OverlaySafeAreaAdjustment {
    private(set) weak var viewController: UIViewController?
    private var consumerBaselineBottom: CGFloat
    private var lastWrittenBottom: CGFloat

    init(viewController: UIViewController) {
        self.viewController = viewController
        consumerBaselineBottom = viewController.additionalSafeAreaInsets.bottom
        lastWrittenBottom = consumerBaselineBottom
    }

    deinit {
        let viewController = viewController
        let consumerBaselineBottom = consumerBaselineBottom
        let lastWrittenBottom = lastWrittenBottom

        // `isolated deinit` requires iOS 18.4. This package supports iOS 18.0,
        // so assert the type's MainActor confinement for the synchronous
        // UIKit cleanup backstop.
        MainActor.assumeIsolated {
            guard let viewController else {
                return
            }
            _ = Self.restore(
                viewController: viewController,
                consumerBaselineBottom: consumerBaselineBottom,
                lastWrittenBottom: lastWrittenBottom
            )
        }
    }

    @discardableResult
    func apply(contribution: CGFloat) -> Bool {
        guard let viewController else {
            return false
        }

        let currentBottom = viewController.additionalSafeAreaInsets.bottom
        if abs(currentBottom - lastWrittenBottom) > 0.5 {
            consumerBaselineBottom = currentBottom
        }

        let desiredBottom = consumerBaselineBottom + contribution
        lastWrittenBottom = desiredBottom
        guard abs(currentBottom - desiredBottom) > 0.5 else {
            return false
        }

        var insets = viewController.additionalSafeAreaInsets
        insets.bottom = desiredBottom
        viewController.additionalSafeAreaInsets = insets
        return true
    }

    @discardableResult
    func restore() -> Bool {
        guard let viewController else {
            return false
        }

        let didRestore = Self.restore(
            viewController: viewController,
            consumerBaselineBottom: consumerBaselineBottom,
            lastWrittenBottom: lastWrittenBottom
        )
        lastWrittenBottom = consumerBaselineBottom
        return didRestore
    }

    private static func restore(
        viewController: UIViewController,
        consumerBaselineBottom: CGFloat,
        lastWrittenBottom: CGFloat
    ) -> Bool {
        let currentBottom = viewController.additionalSafeAreaInsets.bottom
        guard abs(currentBottom - lastWrittenBottom) <= 0.5,
              abs(currentBottom - consumerBaselineBottom) > 0.5 else {
            return false
        }

        var insets = viewController.additionalSafeAreaInsets
        insets.bottom = consumerBaselineBottom
        viewController.additionalSafeAreaInsets = insets
        return true
    }
}
