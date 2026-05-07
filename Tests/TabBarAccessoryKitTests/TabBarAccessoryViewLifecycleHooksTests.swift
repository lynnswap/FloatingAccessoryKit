import Testing
import UIKit
@testable import TabBarAccessoryKit

@MainActor
@Suite(.serialized)
struct TabBarAccessoryViewLifecycleHooksTests {
    @Test func lifecycleUpdatesOnlyMatchingTabBarController() {
        let firstTabBarController = makeTestTabBarController()
        let secondTabBarController = makeTestTabBarController()
        let firstCoordinator = SpyAccessoryCoordinator()
        let secondCoordinator = SpyAccessoryCoordinator()

        TabBarAccessoryViewLifecycleHooks.register(firstCoordinator, for: firstTabBarController)
        TabBarAccessoryViewLifecycleHooks.register(secondCoordinator, for: secondTabBarController)

        firstTabBarController.viewDidLayoutSubviews()

        #expect(firstCoordinator.updateCallCount == 1)
        #expect(firstCoordinator.lastUpdatedTabBarController === firstTabBarController)
        #expect(secondCoordinator.updateCallCount == 0)
    }

    @Test func registeringSameCoordinatorTwiceDoesNotDuplicateCallbacks() {
        let tabBarController = makeTestTabBarController()
        let coordinator = SpyAccessoryCoordinator()

        TabBarAccessoryViewLifecycleHooks.register(coordinator, for: tabBarController)
        TabBarAccessoryViewLifecycleHooks.register(coordinator, for: tabBarController)

        tabBarController.viewDidLayoutSubviews()
        #expect(coordinator.updateCallCount == 1)

        tabBarController.setTabBarHidden(true, animated: false)
        #expect(coordinator.visibilityChangeCallCount == 1)
    }

    @Test func safeAreaAndViewIsAppearingCallbacksUpdateRegisteredCoordinator() {
        let tabBarController = makeTestTabBarController()
        let coordinator = SpyAccessoryCoordinator()

        TabBarAccessoryViewLifecycleHooks.register(coordinator, for: tabBarController)

        tabBarController.viewSafeAreaInsetsDidChange()
        tabBarController.viewIsAppearing(false)

        #expect(coordinator.updateCallCount == 2)
        #expect(coordinator.lastUpdatedTabBarController === tabBarController)
    }

    @Test func setTabBarHiddenNotifiesVisibilityChange() {
        let tabBarController = makeTestTabBarController()
        let coordinator = SpyAccessoryCoordinator()

        TabBarAccessoryViewLifecycleHooks.register(coordinator, for: tabBarController)

        tabBarController.setTabBarHidden(true, animated: false)

        #expect(coordinator.visibilityChangeCallCount == 1)
        #expect(coordinator.lastVisibilityHidden == true)
        #expect(coordinator.lastVisibilityAnimated == false)
        #expect(coordinator.lastVisibilityTabBarController === tabBarController)
    }

    @Test func setTabBarHiddenPreservesAnimatedFlagInVisibilityCallback() {
        let tabBarController = makeTestTabBarController()
        let coordinator = SpyAccessoryCoordinator()

        TabBarAccessoryViewLifecycleHooks.register(coordinator, for: tabBarController)

        tabBarController.setTabBarHidden(true, animated: true)

        #expect(coordinator.visibilityChangeCallCount == 1)
        #expect(coordinator.lastVisibilityHidden == true)
        #expect(coordinator.lastVisibilityAnimated == true)
    }

    @Test func registrationDoesNotRetainCoordinatorOrTabBarController() async {
        weak var weakTabBarController: UITabBarController?
        weak var weakCoordinator: SpyAccessoryCoordinator?

        do {
            let tabBarController = makeTestTabBarController()
            let coordinator = SpyAccessoryCoordinator()

            TabBarAccessoryViewLifecycleHooks.register(coordinator, for: tabBarController)

            weakTabBarController = tabBarController
            weakCoordinator = coordinator
        }

        await Task.yield()

        #expect(weakTabBarController == nil)
        #expect(weakCoordinator == nil)
    }
}
