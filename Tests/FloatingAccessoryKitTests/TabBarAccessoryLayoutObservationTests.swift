import Testing
import UIKit
@testable import FloatingAccessoryKit

@MainActor
@Suite
struct TabBarAccessoryLayoutObservationTests {
    @Test func installingObservationOnVisibleHostCreatesOneObservationView() {
        let tabBarController = makeTestTabBarController()
        let window = UIWindow(frame: tabBarController.view.bounds)
        window.rootViewController = tabBarController
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let renderer = SpyAccessoryRenderer()
        let controller = TabBarAccessoryController(
            tabBarController: tabBarController,
            renderer: renderer
        )

        controller.setContentView(UIView())

        let observationViews = tabBarController.view.subviews.compactMap {
            $0 as? TabBarAccessoryLayoutObservationView
        }
        #expect(observationViews.count == 1)
        #expect(renderer.updateCallCount == 0)
    }

    @Test func tabBarAppearanceChangeUpdatesInstalledOverlayBackground() throws {
        guard #unavailable(iOS 26.0) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let controller = tabBarController.floatingAccessoryController
        controller.setContentView(FixedSizeView(size: CGSize(width: 44, height: 44)))
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .systemPink

        tabBarController.tabBar.standardAppearance = appearance

        let hostView = try #require(overlayHostViews(in: tabBarController).first)
        let backgroundView = try #require(
            hostView.subviews.first { !($0 is UIVisualEffectView) }
        )
        #expect(backgroundView.backgroundColor?.isEqual(UIColor.systemPink) == true)
    }

    @Test func viewControllerReplacementTriggersOwnedLayoutUpdate() {
        guard #unavailable(iOS 26.0) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let renderer = SpyAccessoryRenderer()
        let controller = TabBarAccessoryController(
            tabBarController: tabBarController,
            renderer: renderer
        )
        controller.setContentView(UIView())
        let baseline = renderer.updateCallCount

        tabBarController.viewControllers = [UIViewController(), UIViewController()]

        #expect(renderer.updateCallCount > baseline)
    }

    @Test func tabBarButtonHeightChangeRemeasuresInstalledOverlay() throws {
        guard #unavailable(iOS 26.0) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let button = addTestTabBarButton(height: 44, to: tabBarController)
        let controller = tabBarController.floatingAccessoryController
        controller.setContentView(FixedSizeView(size: CGSize(width: 88, height: 44)))
        tabBarController.view.layoutIfNeeded()
        let hostView = try #require(overlayHostViews(in: tabBarController).first)

        button.frame.size.height = 64
        tabBarController.view.layoutIfNeeded()

        #expect(abs(hostView.bounds.height - 64) <= 0.5)
    }

    @Test func layoutObservationUpdatesOnlyItsOwningController() {
        let firstTabBarController = makeTestTabBarController()
        let secondTabBarController = makeTestTabBarController()
        let firstRenderer = SpyAccessoryRenderer()
        let secondRenderer = SpyAccessoryRenderer()
        let firstController = TabBarAccessoryController(
            tabBarController: firstTabBarController,
            renderer: firstRenderer
        )
        let secondController = TabBarAccessoryController(
            tabBarController: secondTabBarController,
            renderer: secondRenderer
        )

        firstController.setContentView(UIView())
        secondController.setContentView(UIView())
        let firstBaseline = firstRenderer.updateCallCount
        let secondBaseline = secondRenderer.updateCallCount

        firstTabBarController.view.setNeedsLayout()
        firstTabBarController.view.layoutIfNeeded()

        #expect(firstRenderer.updateCallCount > firstBaseline)
        #expect(secondRenderer.updateCallCount == secondBaseline)
    }

    @Test func tabBarFrameChangeTriggersOwnedLayoutUpdate() {
        guard #unavailable(iOS 26.0) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let renderer = SpyAccessoryRenderer()
        let controller = TabBarAccessoryController(
            tabBarController: tabBarController,
            renderer: renderer
        )

        controller.setContentView(UIView())
        let baseline = renderer.updateCallCount

        tabBarController.tabBar.frame = tabBarController.tabBar.frame.offsetBy(
            dx: 0,
            dy: -12
        )

        #expect(renderer.updateCallCount > baseline)
    }

    @Test func selectedViewControllerChangeTriggersOwnedLayoutUpdate() {
        let firstViewController = UIViewController()
        let secondViewController = UIViewController()
        let tabBarController = makeTestTabBarController(
            viewControllers: [firstViewController, secondViewController]
        )
        let renderer = SpyAccessoryRenderer()
        let controller = TabBarAccessoryController(
            tabBarController: tabBarController,
            renderer: renderer
        )

        controller.setContentView(UIView())
        tabBarController.view.layoutIfNeeded()
        let baseline = renderer.updateCallCount

        tabBarController.selectedViewController = secondViewController
        tabBarController.view.layoutIfNeeded()

        #expect(renderer.updateCallCount > baseline)
    }

    @Test func selectedSafeAreaObservationMovesWithSelection() {
        guard #unavailable(iOS 26.0) else {
            return
        }

        let firstViewController = UIViewController()
        let secondViewController = UIViewController()
        let tabBarController = makeTestTabBarController(
            viewControllers: [firstViewController, secondViewController]
        )
        let controller = tabBarController.floatingAccessoryController

        controller.setContentView(UIView())

        #expect(layoutObservationViewCount(in: firstViewController.view) == 1)
        #expect(layoutObservationViewCount(in: secondViewController.view) == 0)

        tabBarController.selectedViewController = secondViewController

        #expect(layoutObservationViewCount(in: firstViewController.view) == 0)
        #expect(layoutObservationViewCount(in: secondViewController.view) == 1)

        controller.removeContent()

        #expect(layoutObservationViewCount(in: secondViewController.view) == 0)
    }

    @Test func consumerSafeAreaWriteReappliesOverlayContribution() {
        guard #unavailable(iOS 26.0) else {
            return
        }

        let selectedViewController = UIViewController()
        let tabBarController = makeTestTabBarController(
            viewControllers: [selectedViewController]
        )
        let window = UIWindow(frame: tabBarController.view.bounds)
        window.rootViewController = tabBarController
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let controller = tabBarController.floatingAccessoryController
        controller.setContentView(
            FixedSizeView(size: CGSize(width: 44, height: 44))
        )
        tabBarController.view.layoutIfNeeded()

        selectedViewController.additionalSafeAreaInsets.bottom = 30
        selectedViewController.view.layoutIfNeeded()
        tabBarController.view.layoutIfNeeded()

        #expect(selectedViewController.additionalSafeAreaInsets.bottom > 30)

        controller.removeContent()

        #expect(selectedViewController.additionalSafeAreaInsets.bottom == 30)
    }

    @Test func hostOwnedControllerDoesNotCreateARetainCycle() async {
        weak var weakTabBarController: UITabBarController?
        weak var weakController: TabBarAccessoryController?

        do {
            let tabBarController = makeTestTabBarController()
            let controller = tabBarController.floatingAccessoryController
            controller.setContentView(UIView())
            weakTabBarController = tabBarController
            weakController = controller
        }

        await Task.yield()

        #expect(weakTabBarController == nil)
        #expect(weakController == nil)
    }

    private func layoutObservationViewCount(in view: UIView) -> Int {
        view.subviews.count { $0 is TabBarAccessoryLayoutObservationView }
    }
}
