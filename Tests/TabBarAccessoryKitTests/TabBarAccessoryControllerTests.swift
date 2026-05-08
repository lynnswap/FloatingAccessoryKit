import Testing
import UIKit
@testable import TabBarAccessoryKit

@MainActor
@Suite
struct TabBarAccessoryControllerTests {
    @Test func setHiddenWithoutContentIsNoOp() {
        let tabBarController = makeTestTabBarController()
        let controller = TabBarAccessoryController(tabBarController: tabBarController)

        controller.setHidden(true, animated: false)
        controller.setHidden(false, animated: false)

        #expect(controller.isHidden == false)
    }

    @Test func setContentInstallsOverlayFallbackWithDefaultTrailingPosition() throws {
        if #available(iOS 26.0, *) {
            return
        }

        let tabBarController = makeTestTabBarController()
        let controller = TabBarAccessoryController(tabBarController: tabBarController)
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        controller.setContent(contentView, animated: false)
        tabBarController.view.layoutIfNeeded()

        let hostView = try #require(contentView.superview)
        let safeAreaFrame = tabBarController.view.safeAreaLayoutGuide.layoutFrame

        #expect(hostView.superview === tabBarController.view)
        #expect(overlayHostViews(in: tabBarController) == [hostView])
        #expect(abs(hostView.frame.maxX - (safeAreaFrame.maxX - 8)) <= 0.5)
        #expect(controller.isHidden == false)
    }

    @Test func setContentInstallsNativeAccessoryWithUITabs() {
        guard #available(iOS 26.0, *) else {
            return
        }

        let tabBarController = makeUITabTestTabBarController()
        let controller = TabBarAccessoryController(tabBarController: tabBarController)
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        controller.setContent(contentView, animated: false)

        #expect(tabBarController.bottomAccessory != nil)
        #expect(overlayHostViews(in: tabBarController).isEmpty)
        #expect(controller.isHidden == false)
    }

    @Test func updatingPositionThroughControllerReusesOverlayContentAndHost() throws {
        if #available(iOS 26.0, *) {
            return
        }

        let tabBarController = makeTestTabBarController()
        let controller = TabBarAccessoryController(tabBarController: tabBarController)
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        controller.setContent(contentView, position: .trailing, animated: false)
        tabBarController.view.layoutIfNeeded()
        let hostView = try #require(contentView.superview)

        controller.setContent(contentView, position: .center, animated: false)
        tabBarController.view.layoutIfNeeded()

        let safeAreaFrame = tabBarController.view.safeAreaLayoutGuide.layoutFrame
        #expect(contentView.superview === hostView)
        #expect(overlayHostViews(in: tabBarController) == [hostView])
        #expect(abs(hostView.frame.midX - safeAreaFrame.midX) <= 0.5)
    }

    @Test func hiddenStateTracksContentVisibility() {
        let tabBarController = makeTestTabBarController()
        let controller = TabBarAccessoryController(tabBarController: tabBarController)
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        controller.setContent(contentView, position: .trailing, animated: false)
        #expect(controller.isHidden == false)

        controller.setHidden(true, animated: false)
        controller.setHidden(true, animated: false)
        #expect(controller.isHidden == true)

        controller.setHidden(false, animated: false)
        controller.setHidden(false, animated: false)
        #expect(controller.isHidden == false)
    }

    @Test func controllerFollowsTabBarHiddenChangesOnOverlayFallback() throws {
        if #available(iOS 26.0, *) {
            return
        }

        let tabBarController = makeTestTabBarController()
        let controller = TabBarAccessoryController(tabBarController: tabBarController)
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        controller.setContent(contentView, position: .trailing, animated: false)
        tabBarController.view.layoutIfNeeded()
        let hostView = try #require(contentView.superview)
        let visibleBottomY = hostView.frame.maxY

        tabBarController.setTabBarHidden(true, animated: false)
        tabBarController.view.layoutIfNeeded()

        let expectedHiddenBottomY = tabBarController.view.safeAreaLayoutGuide.layoutFrame.maxY - 8
        #expect(abs(hostView.frame.maxY - expectedHiddenBottomY) <= 0.5)
        #expect(hostView.frame.maxY > visibleBottomY)

        tabBarController.setTabBarHidden(false, animated: false)
        tabBarController.view.layoutIfNeeded()

        #expect(abs(hostView.frame.maxY - visibleBottomY) <= 0.5)
    }

    @Test func setContentNilClearsHiddenState() {
        let tabBarController = makeTestTabBarController()
        let controller = TabBarAccessoryController(tabBarController: tabBarController)
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        controller.setContent(contentView, position: .trailing, animated: false)
        controller.setHidden(true, animated: false)
        controller.setContent(nil, animated: false)

        #expect(controller.isHidden == false)
    }

    @Test func setContentNilRestoresAutoresizingMaskOnOverlayFallback() {
        if #available(iOS 26.0, *) {
            return
        }

        let tabBarController = makeTestTabBarController()
        let controller = TabBarAccessoryController(tabBarController: tabBarController)
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        #expect(contentView.translatesAutoresizingMaskIntoConstraints == true)

        controller.setContent(contentView, position: .trailing, animated: false)
        #expect(contentView.translatesAutoresizingMaskIntoConstraints == false)

        controller.setContent(nil, animated: false)
        #expect(contentView.superview == nil)
        #expect(contentView.translatesAutoresizingMaskIntoConstraints == true)
    }

    @Test func setContentNilRemovesOverlayHostInstalledThroughController() throws {
        if #available(iOS 26.0, *) {
            return
        }

        let tabBarController = makeTestTabBarController()
        let controller = TabBarAccessoryController(tabBarController: tabBarController)
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        controller.setContent(contentView, position: .trailing, animated: false)
        tabBarController.view.layoutIfNeeded()
        let hostView = try #require(contentView.superview)

        controller.setContent(nil, animated: false)

        #expect(contentView.superview == nil)
        #expect(hostView.superview == nil)
        #expect(overlayHostViews(in: tabBarController).isEmpty)
    }

    @Test func controllerItselfIsNotRetainedByRegisteredLifecycleHooks() {
        weak var weakController: TabBarAccessoryController?

        do {
            let tabBarController = makeTestTabBarController()
            let controller = TabBarAccessoryController(tabBarController: tabBarController)
            let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

            controller.setContent(contentView, position: .trailing, animated: false)
            controller.setContent(nil, animated: false)

            weakController = controller
        }

        #expect(weakController == nil)
    }
}
