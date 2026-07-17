import Testing
import UIKit
@testable import FloatingAccessoryKit

@MainActor
@Suite
struct TabBarAccessoryControllerTests {
    @Test func reentrantStateChangeIsRenderedAfterActiveRender() {
        let tabBarController = makeTestTabBarController()
        let renderer = ReentrantAccessoryRenderer()
        let controller = TabBarAccessoryController(
            tabBarController: tabBarController,
            renderer: renderer
        )
        renderer.onNextRender = {
            controller.setPosition(.center, animated: true)
        }

        controller.setContentView(
            FixedSizeView(size: CGSize(width: 44, height: 44)),
            position: .trailing
        )

        #expect(renderer.renderedStates.count == 2)
        #expect(renderer.renderedStates.last?.position == .center)
        #expect(renderer.renderAnimations == [false, true])
        #expect(controller.position == .center)
    }

    @Test func ownershipLossDoesNotDiscardReentrantReplacement() {
        let tabBarController = makeTestTabBarController()
        let renderer = ReentrantAccessoryRenderer()
        let controller = TabBarAccessoryController(
            tabBarController: tabBarController,
            renderer: renderer
        )
        let firstView = FixedSizeView(size: CGSize(width: 44, height: 44))
        let replacementView = FixedSizeView(size: CGSize(width: 88, height: 44))
        renderer.nextRenderResult = .ownershipLost
        renderer.onNextRender = {
            controller.setContentView(replacementView)
        }

        controller.setContentView(firstView)

        #expect(renderer.renderedStates.count == 2)
        #expect(renderer.renderedStates.last?.contentView === replacementView)
        #expect(controller.contentView === replacementView)
    }

    @Test func reentrantLayoutInvalidationIsUpdatedAfterActiveUpdate() {
        let tabBarController = makeTestTabBarController()
        let renderer = ReentrantAccessoryRenderer()
        let controller = TabBarAccessoryController(
            tabBarController: tabBarController,
            renderer: renderer
        )
        controller.setContentView(
            FixedSizeView(size: CGSize(width: 44, height: 44))
        )
        tabBarController.view.layoutIfNeeded()
        let baselineUpdateCount = renderer.updatedStates.count
        renderer.onNextUpdate = {
            renderer.contentSizeInvalidationHandler?(true)
        }

        renderer.contentSizeInvalidationHandler?(false)

        #expect(renderer.updatedStates.count == baselineUpdateCount + 2)
        let reentrantAnimationDurations = renderer.updateAnimationDurations
            .dropFirst(baselineUpdateCount)
        #expect(reentrantAnimationDurations.first == 0)
        #expect((reentrantAnimationDurations.last ?? 0) > 0)
    }

    @Test func contentUpdatePreservesAnimationIntent() {
        let tabBarController = makeTestTabBarController()
        let renderer = SpyAccessoryRenderer()
        let controller = TabBarAccessoryController(
            tabBarController: tabBarController,
            renderer: renderer
        )
        controller.setContentView(
            FixedSizeView(size: CGSize(width: 44, height: 44))
        )
        tabBarController.view.layoutIfNeeded()
        let baselineUpdateCount = renderer.updateCallCount

        var updateAnimationDurations: [TimeInterval] = []
        controller.performContentUpdate(animated: false) {
            updateAnimationDurations.append(UIView.inheritedAnimationDuration)
        }
        controller.performContentUpdate(animated: true) {
            updateAnimationDurations.append(UIView.inheritedAnimationDuration)
        }

        #expect(renderer.updateCallCount == baselineUpdateCount + 2)
        let animationDurations = renderer.updateAnimationDurations
            .dropFirst(baselineUpdateCount)
        #expect(animationDurations.first == 0)
        #expect((animationDurations.last ?? 0) > 0)
        #expect(updateAnimationDurations.first == 0)
        #expect((updateAnimationDurations.last ?? 0) > 0)
    }

    @Test func contentUpdateRespectsReduceMotion() {
        let tabBarController = makeTestTabBarController()
        let renderer = SpyAccessoryRenderer()
        let controller = TabBarAccessoryController(
            tabBarController: tabBarController,
            renderer: renderer,
            isReduceMotionEnabled: { true }
        )
        controller.setContentView(
            FixedSizeView(size: CGSize(width: 44, height: 44))
        )
        tabBarController.view.layoutIfNeeded()
        let baselineUpdateCount = renderer.updateCallCount

        var didUpdate = false
        UIView.animate(withDuration: 1) {
            controller.performContentUpdate(animated: true) {
                didUpdate = true
            }
        }

        #expect(didUpdate)
        #expect(renderer.updateCallCount == baselineUpdateCount + 1)
        #expect(renderer.updateAnimationDurations.last == 0)
    }

    @Test func contentUpdateWithoutContentExecutesWithoutRendering() {
        let tabBarController = makeTestTabBarController()
        let renderer = SpyAccessoryRenderer()
        let controller = TabBarAccessoryController(
            tabBarController: tabBarController,
            renderer: renderer
        )

        var didUpdate = false
        controller.performContentUpdate {
            didUpdate = true
        }

        #expect(didUpdate)
        #expect(renderer.renderCallCount == 0)
        #expect(renderer.updateCallCount == 0)
    }

    @Test func contentMutationPrecedesRendererInvalidation() {
        let tabBarController = makeTestTabBarController()
        let renderer = SpyAccessoryRenderer()
        let controller = TabBarAccessoryController(
            tabBarController: tabBarController,
            renderer: renderer
        )
        controller.setContentView(
            FixedSizeView(size: CGSize(width: 44, height: 44))
        )
        var didMutate = false
        renderer.onInvalidateContentSize = {
            #expect(didMutate)
        }

        controller.performContentUpdate(animated: false) {
            didMutate = true
        }

        #expect(didMutate)
    }

    @Test func stateOnlyPreconfigurationDoesNotRender() {
        let tabBarController = UITabBarController()
        let renderer = SpyAccessoryRenderer()
        let controller = TabBarAccessoryController(
            tabBarController: tabBarController,
            renderer: renderer
        )

        controller.setPosition(.center)
        controller.setHidden(true)

        #expect(renderer.renderCallCount == 0)
        #expect(renderer.updateCallCount == 0)
        #expect(controller.position == .center)
        #expect(controller.isHidden == true)
    }

    @Test func requestedVisibilityIsRetainedWhileContentIsAbsent() {
        let tabBarController = makeTestTabBarController()
        let controller = tabBarController.floatingAccessoryController

        controller.setHidden(true, animated: false)
        #expect(controller.isHidden == true)

        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))
        controller.setContentView(contentView)

        #expect(controller.contentView === contentView)
        #expect(controller.isHidden == true)
        if #available(iOS 26.0, *) {
            #expect(tabBarController.bottomAccessory == nil)
        }
    }

    @Test func accessorReturnsOneStableControllerPerHost() {
        let tabBarController = makeTestTabBarController()

        let first = tabBarController.floatingAccessoryController
        let second = tabBarController.floatingAccessoryController

        #expect(first === second)
    }

    @Test func setContentInstallsOverlayFallbackWithDefaultTrailingPosition() throws {
        if #available(iOS 26.0, *) {
            return
        }

        let tabBarController = makeTestTabBarController()
        let controller = tabBarController.floatingAccessoryController
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        controller.setContentView(contentView, animated: false)
        tabBarController.view.layoutIfNeeded()

        let contentHostView = try #require(contentView.superview)
        let hostView = try #require(contentHostView.superview)
        let safeAreaFrame = tabBarController.view.safeAreaLayoutGuide.layoutFrame

        #expect(hostView.superview === tabBarController.view)
        #expect(overlayHostViews(in: tabBarController) == [hostView])
        if tabBarController.view.effectiveUserInterfaceLayoutDirection == .leftToRight {
            #expect(abs(hostView.frame.maxX - (safeAreaFrame.maxX - 8)) <= 0.5)
        } else {
            #expect(abs(hostView.frame.minX - (safeAreaFrame.minX + 8)) <= 0.5)
        }
        #expect(controller.isHidden == false)
    }

    @Test func setContentInstallsNativeAccessoryWithUITabs() {
        guard #available(iOS 26.0, *) else {
            return
        }

        let tabBarController = makeUITabTestTabBarController()
        let controller = tabBarController.floatingAccessoryController
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        controller.setContentView(contentView, animated: false)

        #expect(tabBarController.bottomAccessory != nil)
        #expect(overlayHostViews(in: tabBarController).isEmpty)
        #expect(controller.isHidden == false)
    }

    @Test func updatingPositionThroughControllerReusesOverlayContentAndHost() throws {
        if #available(iOS 26.0, *) {
            return
        }

        let tabBarController = makeTestTabBarController()
        let controller = tabBarController.floatingAccessoryController
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        controller.setContentView(contentView, position: .trailing, animated: false)
        tabBarController.view.layoutIfNeeded()
        let contentHostView = try #require(contentView.superview)
        let hostView = try #require(contentHostView.superview)

        controller.setPosition(.center, animated: false)
        tabBarController.view.layoutIfNeeded()

        let safeAreaFrame = tabBarController.view.safeAreaLayoutGuide.layoutFrame
        #expect(contentView.superview === contentHostView)
        #expect(overlayHostViews(in: tabBarController) == [hostView])
        #expect(abs(hostView.frame.midX - safeAreaFrame.midX) <= 0.5)
    }

    @Test func hiddenStateTracksContentVisibility() {
        let tabBarController = makeTestTabBarController()
        let controller = tabBarController.floatingAccessoryController
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        controller.setContentView(contentView, position: .trailing, animated: false)
        #expect(controller.isHidden == false)

        controller.setHidden(true, animated: false)
        controller.setHidden(true, animated: false)
        #expect(controller.isHidden == true)

        controller.setHidden(false, animated: false)
        controller.setHidden(false, animated: false)
        #expect(controller.isHidden == false)
    }

    @Test func externalReparentingDuringSemanticUpdateClearsRecordedContent() {
        let tabBarController = makeTestTabBarController()
        let controller = tabBarController.floatingAccessoryController
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))
        let newOwner = UIView()

        controller.setContentView(contentView, position: .trailing, animated: false)
        tabBarController.view.layoutIfNeeded()
        newOwner.addSubview(contentView)

        controller.setPosition(.center, animated: false)

        #expect(contentView.superview === newOwner)
        #expect(contentView.translatesAutoresizingMaskIntoConstraints == false)
        #expect(controller.contentView == nil)
        if #available(iOS 26.0, *) {
            #expect(tabBarController.bottomAccessory == nil)
        } else {
            #expect(overlayHostViews(in: tabBarController).isEmpty)
        }
    }

    @Test func installingSharedContentRelinquishesPreviousController() {
        let firstTabBarController = makeTestTabBarController()
        let secondTabBarController = makeTestTabBarController()
        let firstController = firstTabBarController.floatingAccessoryController
        let secondController = secondTabBarController.floatingAccessoryController
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))
        contentView.translatesAutoresizingMaskIntoConstraints = true

        firstController.setContentView(contentView, animated: false)
        secondController.setContentView(contentView, animated: false)

        #expect(firstController.contentView == nil)
        #expect(secondController.contentView === contentView)
        #expect(contentView.superview is AccessoryContentHostView)
        #expect(contentView.translatesAutoresizingMaskIntoConstraints == false)
        if #available(iOS 26.0, *) {
            #expect(firstTabBarController.bottomAccessory == nil)
        } else {
            #expect(overlayHostViews(in: firstTabBarController).isEmpty)
        }

        secondController.removeContent(animated: false)

        #expect(contentView.superview == nil)
        #expect(contentView.translatesAutoresizingMaskIntoConstraints == true)
    }

    @Test func controllerCoordinatesTabBarHiddenChangesOnOverlayFallback() throws {
        if #available(iOS 26.0, *) {
            return
        }

        let tabBarController = makeTestTabBarController()
        let controller = tabBarController.floatingAccessoryController
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        controller.setContentView(contentView, position: .trailing, animated: false)
        tabBarController.view.layoutIfNeeded()
        let contentHostView = try #require(contentView.superview)
        let hostView = try #require(contentHostView.superview)
        let visibleBottomY = hostView.frame.maxY

        controller.setTabBarHidden(true, animated: false)
        tabBarController.view.layoutIfNeeded()

        let expectedHiddenBottomY = tabBarController.view.safeAreaLayoutGuide.layoutFrame.maxY - 8
        #expect(abs(hostView.frame.maxY - expectedHiddenBottomY) <= 0.5)
        #expect(hostView.frame.maxY > visibleBottomY)

        controller.setTabBarHidden(false, animated: false)
        tabBarController.view.layoutIfNeeded()

        #expect(abs(hostView.frame.maxY - visibleBottomY) <= 0.5)
    }

    @Test func tappingRevealHitAreaShowsHiddenTabBarOnOverlayFallback() throws {
        if #available(iOS 26.0, *) {
            return
        }

        let tabBarController = makeTestTabBarController()
        let controller = tabBarController.floatingAccessoryController
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        controller.setContentView(contentView, position: .trailing, animated: false)
        tabBarController.view.layoutIfNeeded()

        controller.setTabBarHidden(true, animated: false)
        tabBarController.view.layoutIfNeeded()

        let hitAreaView = try #require(revealHitAreaViews(in: tabBarController).first)
        #expect(tabBarController.isTabBarHidden == true)

        hitAreaView.revealTabBar()

        #expect(tabBarController.isTabBarHidden == false)
    }

    @Test func longPressingRevealHitAreaShowsHiddenTabBarOnOverlayFallback() throws {
        if #available(iOS 26.0, *) {
            return
        }

        let tabBarController = makeTestTabBarController()
        let controller = tabBarController.floatingAccessoryController
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        controller.setContentView(contentView, position: .trailing, animated: false)
        tabBarController.view.layoutIfNeeded()

        controller.setTabBarHidden(true, animated: false)
        tabBarController.view.layoutIfNeeded()

        let hitAreaView = try #require(revealHitAreaViews(in: tabBarController).first)
        let longPressGesture = TestLongPressGestureRecognizer()
        longPressGesture.transition(to: .began)

        #expect(tabBarController.isTabBarHidden == true)

        hitAreaView.handleLongPress(longPressGesture)

        #expect(tabBarController.isTabBarHidden == false)
    }

    @Test func accessibilityActivatingRevealHitAreaShowsHiddenTabBarOnOverlayFallback() throws {
        if #available(iOS 26.0, *) {
            return
        }

        let tabBarController = makeTestTabBarController()
        let controller = tabBarController.floatingAccessoryController
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        controller.setContentView(contentView, position: .trailing, animated: false)
        tabBarController.view.layoutIfNeeded()

        controller.setTabBarHidden(true, animated: false)
        tabBarController.view.layoutIfNeeded()

        let hitAreaView = try #require(revealHitAreaViews(in: tabBarController).first)
        #expect(tabBarController.isTabBarHidden == true)

        let didActivate = hitAreaView.accessibilityActivate()

        #expect(didActivate == true)
        #expect(tabBarController.isTabBarHidden == false)
    }

    @Test func removingAndReplacingContentPreservesRequestedVisibility() {
        let tabBarController = makeTestTabBarController()
        let controller = tabBarController.floatingAccessoryController
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        controller.setContentView(contentView, position: .trailing, animated: false)
        controller.setHidden(true, animated: false)
        controller.removeContent(animated: false)

        #expect(controller.contentView == nil)
        #expect(controller.isHidden == true)

        let replacement = FixedSizeView(size: CGSize(width: 44, height: 44))
        controller.setContentView(replacement, animated: false)

        #expect(controller.contentView === replacement)
        #expect(controller.isHidden == true)
    }

    @Test func removeContentRestoresAutoresizingMaskOnOverlayFallback() {
        if #available(iOS 26.0, *) {
            return
        }

        let tabBarController = makeTestTabBarController()
        let controller = tabBarController.floatingAccessoryController
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        #expect(contentView.translatesAutoresizingMaskIntoConstraints == true)

        controller.setContentView(contentView, position: .trailing, animated: false)
        #expect(contentView.translatesAutoresizingMaskIntoConstraints == false)

        controller.removeContent(animated: false)
        #expect(contentView.superview == nil)
        #expect(contentView.translatesAutoresizingMaskIntoConstraints == true)
    }

    @Test func removeContentRemovesOverlayHostInstalledThroughController() throws {
        if #available(iOS 26.0, *) {
            return
        }

        let tabBarController = makeTestTabBarController()
        let controller = tabBarController.floatingAccessoryController
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        controller.setContentView(contentView, position: .trailing, animated: false)
        tabBarController.view.layoutIfNeeded()
        let contentHostView = try #require(contentView.superview)
        let hostView = try #require(contentHostView.superview)

        controller.removeContent(animated: false)

        #expect(contentView.superview == nil)
        #expect(hostView.superview == nil)
        #expect(overlayHostViews(in: tabBarController).isEmpty)
    }

    @Test func hostOwnedControllerIsReleasedWithItsHost() async {
        weak var weakController: TabBarAccessoryController?

        do {
            let tabBarController = makeTestTabBarController()
            let controller = tabBarController.floatingAccessoryController
            let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

            controller.setContentView(contentView, position: .trailing, animated: false)
            controller.removeContent(animated: false)

            weakController = controller
        }

        await Task.yield()

        #expect(weakController == nil)
    }
}
