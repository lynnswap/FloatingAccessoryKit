import Testing
import UIKit
@testable import FloatingAccessoryKit

@MainActor
@Suite
struct OverlaySafeAreaAdjustmentTests {
    @Test func deinitializationRestoresContribution() {
        let viewController = UIViewController()
        viewController.additionalSafeAreaInsets.bottom = 12
        var adjustment: OverlaySafeAreaAdjustment? = OverlaySafeAreaAdjustment(
            viewController: viewController
        )

        adjustment?.apply(contribution: 56)
        #expect(viewController.additionalSafeAreaInsets.bottom == 68)

        adjustment = nil

        #expect(viewController.additionalSafeAreaInsets.bottom == 12)
    }

    @Test func appliesAndRestoresContributionFromConsumerBaseline() {
        let viewController = UIViewController()
        viewController.additionalSafeAreaInsets = UIEdgeInsets(
            top: 1,
            left: 2,
            bottom: 12,
            right: 3
        )
        let adjustment = OverlaySafeAreaAdjustment(viewController: viewController)

        adjustment.apply(contribution: 56)
        #expect(viewController.additionalSafeAreaInsets == UIEdgeInsets(
            top: 1,
            left: 2,
            bottom: 68,
            right: 3
        ))

        adjustment.restore()
        #expect(viewController.additionalSafeAreaInsets == UIEdgeInsets(
            top: 1,
            left: 2,
            bottom: 12,
            right: 3
        ))
    }

    @Test func consumerWriteBecomesNewBaselineOnNextApply() {
        let viewController = UIViewController()
        viewController.additionalSafeAreaInsets.bottom = 10
        let adjustment = OverlaySafeAreaAdjustment(viewController: viewController)

        adjustment.apply(contribution: 56)
        viewController.additionalSafeAreaInsets.bottom = 30
        adjustment.apply(contribution: 56)

        #expect(viewController.additionalSafeAreaInsets.bottom == 86)
        adjustment.restore()
        #expect(viewController.additionalSafeAreaInsets.bottom == 30)
    }

    @Test func restoreDoesNotOverwriteUnobservedConsumerWrite() {
        let viewController = UIViewController()
        viewController.additionalSafeAreaInsets.bottom = 10
        let adjustment = OverlaySafeAreaAdjustment(viewController: viewController)

        adjustment.apply(contribution: 56)
        viewController.additionalSafeAreaInsets.bottom = 30

        #expect(adjustment.restore() == false)
        #expect(viewController.additionalSafeAreaInsets.bottom == 30)
    }

    @Test func changingContributionDoesNotChangeBaseline() {
        let viewController = UIViewController()
        viewController.additionalSafeAreaInsets.bottom = 10
        let adjustment = OverlaySafeAreaAdjustment(viewController: viewController)

        adjustment.apply(contribution: 40)
        adjustment.apply(contribution: 60)

        #expect(viewController.additionalSafeAreaInsets.bottom == 70)
        adjustment.restore()
        #expect(viewController.additionalSafeAreaInsets.bottom == 10)
    }
}
