import Testing
import UIKit
@testable import FloatingAccessoryKit

@MainActor
@Suite
struct OverlayTabBarAccessoryRendererTests {
    @Test func hiddenRequestWithoutContentDoesNotInstallPresentation() {
        guard #unavailable(iOS 26.0) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let renderer = AccessoryRendererHarness(
            renderer: OverlayTabBarAccessoryRenderer()
        )

        renderer.setHidden(true, animated: false, in: tabBarController)

        #expect(renderer.isHidden)
        #expect(overlayHostViews(in: tabBarController).isEmpty)
    }

    @Test func positionsContentAlongEffectiveLayoutDirection() throws {
        let tabBarController = makeTestTabBarController()
        let renderer = AccessoryRendererHarness(
            renderer: OverlayTabBarAccessoryRenderer()
        )
        let contentView = FixedSizeView(size: CGSize(width: 88, height: 44))

        renderer.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()
        renderer.update(in: tabBarController)
        tabBarController.view.layoutIfNeeded()

        let hostView = try installedHost(for: contentView)
        let safeAreaFrame = tabBarController.view.safeAreaLayoutGuide.layoutFrame
        let trailingMidX = hostView.frame.midX

        renderer.setAccessoryView(
            contentView,
            position: .center,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()
        renderer.update(in: tabBarController)
        tabBarController.view.layoutIfNeeded()
        #expect(abs(hostView.frame.midX - safeAreaFrame.midX) <= 0.5)
        let centerMidX = hostView.frame.midX

        renderer.setAccessoryView(
            contentView,
            position: .leading,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()
        renderer.update(in: tabBarController)
        tabBarController.view.layoutIfNeeded()
        let leadingMidX = hostView.frame.midX

        if tabBarController.view.effectiveUserInterfaceLayoutDirection == .leftToRight {
            #expect(leadingMidX < centerMidX)
            #expect(centerMidX < trailingMidX)
        } else {
            #expect(trailingMidX < centerMidX)
            #expect(centerMidX < leadingMidX)
        }
    }

    @Test func leadingAndTrailingFollowRightToLeftLayoutDirection() throws {
        guard #unavailable(iOS 26.0) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let window = UIWindow(frame: tabBarController.view.bounds)
        window.rootViewController = tabBarController
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        tabBarController.view.semanticContentAttribute = .forceRightToLeft
        tabBarController.view.setNeedsLayout()
        tabBarController.view.layoutIfNeeded()
        #expect(
            tabBarController.view.effectiveUserInterfaceLayoutDirection
                == .rightToLeft
        )
        let renderer = AccessoryRendererHarness(
            renderer: OverlayTabBarAccessoryRenderer()
        )
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        renderer.setAccessoryView(
            contentView,
            position: .leading,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()

        let hostView = try installedHost(for: contentView)
        let safeAreaFrame = tabBarController.view.safeAreaLayoutGuide.layoutFrame
        let horizontalConstraint = try #require(
            tabBarController.view.constraints.first { constraint in
                constraint.isActive
                    && constraint.firstItem === hostView
                    && constraint.firstAttribute == .centerX
            }
        )
        #expect(horizontalConstraint.secondAttribute == .left)
        #expect(abs(hostView.frame.maxX - (safeAreaFrame.maxX - 8)) <= 0.5)
    }

    @Test func contentSizeChangesWithoutResubmission() throws {
        guard #unavailable(iOS 26.0) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let controller = tabBarController.floatingAccessoryController
        let contentView = MutableSizeView(size: CGSize(width: 44, height: 44))

        controller.setContentView(contentView)
        tabBarController.view.layoutIfNeeded()
        let contentHost = try #require(contentView.superview as? AccessoryContentHostView)
        let hostView = try installedHost(for: contentView)
        let initialSize = hostView.bounds.size

        contentView.size = CGSize(width: 132, height: 44)
        contentHost.setNeedsLayout()
        contentHost.layoutIfNeeded()
        tabBarController.view.layoutIfNeeded()

        #expect(hostView.bounds.width > initialSize.width)
        #expect(hostView.bounds.height == initialSize.height)
        #expect(controller.contentView === contentView)
    }

    @Test func contentWithoutPreferredSizeUsesFiniteFallback() throws {
        guard #unavailable(iOS 26.0) else {
            return
        }

        let tabBarController = makeEmptyTestTabBarController()
        let renderer = AccessoryRendererHarness(
            renderer: OverlayTabBarAccessoryRenderer()
        )
        let contentView = NoIntrinsicSizeView()

        renderer.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()

        let hostView = try installedHost(for: contentView)
        #expect(hostView.bounds.width.isFinite && hostView.bounds.width >= 48)
        #expect(hostView.bounds.height.isFinite && hostView.bounds.height >= 48)
    }

    @Test func tabBarButtonHeightDrivesAccessoryHeight() throws {
        guard #unavailable(iOS 26.0) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        _ = addTestTabBarButton(height: 64, to: tabBarController)
        let renderer = AccessoryRendererHarness(
            renderer: OverlayTabBarAccessoryRenderer()
        )
        let contentView = FixedSizeView(size: CGSize(width: 88, height: 44))

        renderer.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()

        let hostView = try installedHost(for: contentView)
        #expect(abs(hostView.bounds.height - 64) <= 0.5)
        #expect(abs(hostView.bounds.width - 128) <= 0.5)
    }

    @Test func hidingAndShowingReusesPresentation() throws {
        guard #unavailable(iOS 26.0) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let renderer = AccessoryRendererHarness(
            renderer: OverlayTabBarAccessoryRenderer()
        )
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        renderer.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        let hostView = try installedHost(for: contentView)

        renderer.setHidden(true, animated: false, in: tabBarController)
        #expect(hostView.isHidden)
        #expect(contentView.superview != nil)

        renderer.setHidden(false, animated: false, in: tabBarController)
        #expect(hostView.isHidden == false)
        #expect(hostView.alpha == 1)
        #expect(try installedHost(for: contentView) === hostView)
    }

    @Test func animatedRemovalDetachesConsumerSynchronously() throws {
        guard #unavailable(iOS 26.0) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let controller = tabBarController.floatingAccessoryController
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        controller.setContentView(contentView)
        let hostView = try installedHost(for: contentView)
        controller.removeContent(animated: true)

        #expect(contentView.superview == nil)
        #expect(hostView.superview == nil)
        #expect(controller.contentView == nil)
    }

    @Test func animatedRemovalCannotRemoveReparentedConsumer() {
        guard #unavailable(iOS 26.0) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let controller = tabBarController.floatingAccessoryController
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))
        let newOwner = UIView()

        controller.setContentView(contentView)
        controller.removeContent(animated: true)
        newOwner.addSubview(contentView)
        tabBarController.view.layoutIfNeeded()

        #expect(contentView.superview === newOwner)
    }

    @Test func externalReparentingRelinquishesOverlayWithoutTouchingNewOwner() throws {
        guard #unavailable(iOS 26.0) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let renderer = AccessoryRendererHarness(
            renderer: OverlayTabBarAccessoryRenderer()
        )
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))
        let newOwner = UIView()

        renderer.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        let hostView = try installedHost(for: contentView)
        newOwner.addSubview(contentView)

        let result = renderer.update(in: tabBarController)

        #expect(result == .ownershipLost)
        #expect(contentView.superview === newOwner)
        #expect(hostView.superview == nil)
    }

    @Test func hiddenTabBarMovesAccessoryAndInstallsRevealHitArea() throws {
        guard #unavailable(iOS 26.0) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let renderer = AccessoryRendererHarness(
            renderer: OverlayTabBarAccessoryRenderer()
        )
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        renderer.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()
        let hostView = try installedHost(for: contentView)
        let visibleBottom = hostView.frame.maxY

        renderer.tabBarVisibilityDidChange(
            hidden: true,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()

        #expect(hostView.frame.maxY > visibleBottom)
        #expect(revealHitAreaViews(in: tabBarController).count == 1)
    }

    @Test func safeAreaContributionMovesWithSelection() {
        guard #unavailable(iOS 26.0) else {
            return
        }

        let first = UIViewController()
        let second = UIViewController()
        first.additionalSafeAreaInsets.bottom = 10
        second.additionalSafeAreaInsets.bottom = 20
        let tabBarController = makeTestTabBarController(
            viewControllers: [first, second]
        )
        let renderer = AccessoryRendererHarness(
            renderer: OverlayTabBarAccessoryRenderer()
        )

        renderer.setAccessoryView(
            FixedSizeView(size: CGSize(width: 44, height: 44)),
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        #expect(first.additionalSafeAreaInsets.bottom > 10)

        tabBarController.selectedIndex = 1
        renderer.update(in: tabBarController)

        #expect(first.additionalSafeAreaInsets.bottom == 10)
        #expect(second.additionalSafeAreaInsets.bottom > 20)
    }

    @Test func repeatedUpdatesReuseInstalledConstraints() throws {
        guard #unavailable(iOS 26.0) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let renderer = AccessoryRendererHarness(
            renderer: OverlayTabBarAccessoryRenderer()
        )
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        renderer.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        let contentHost = try #require(contentView.superview)
        let hostView = try installedHost(for: contentView)
        let initialConstraintIDs = constraintIDs(in: [
            tabBarController.view,
            hostView,
            contentHost
        ])

        for _ in 0..<5 {
            renderer.update(in: tabBarController)
        }

        #expect(constraintIDs(in: [
            tabBarController.view,
            hostView,
            contentHost
        ]) == initialConstraintIDs)
    }

    private func installedHost(for contentView: UIView) throws -> OverlayAccessoryHostView {
        let contentHost = try #require(contentView.superview as? AccessoryContentHostView)
        return try #require(contentHost.superview as? OverlayAccessoryHostView)
    }
}
