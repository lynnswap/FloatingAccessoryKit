import Testing
import UIKit
@testable import FloatingAccessoryKit

@MainActor
@Suite
struct OverlayTabBarAccessoryCoordinatorTests {
    @Test func setHiddenWithoutContentDoesNotInstallHost() {
        let tabBarController = makeTestTabBarController()
        let coordinator = OverlayTabBarAccessoryCoordinator()

        coordinator.setHidden(true, animated: false, in: tabBarController)

        #expect(coordinator.isHidden == false)
        #expect(overlayHostViews(in: tabBarController).isEmpty)
    }

    @Test func positionsAccessoryAboveVisibleTabBar() throws {
        let tabBarController = makeTestTabBarController()
        let coordinator = OverlayTabBarAccessoryCoordinator()
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()

        let hostView = try #require(contentView.superview)
        let tabBarFrame = tabBarController.tabBar.convert(
            tabBarController.tabBar.bounds,
            to: tabBarController.view
        )
        let safeAreaFrame = tabBarController.view.safeAreaLayoutGuide.layoutFrame

        #expect(abs(hostView.frame.maxY - (tabBarFrame.minY - 8)) <= 0.5)
        #expect(abs(hostView.frame.maxX - (safeAreaFrame.maxX - 8)) <= 0.5)
    }

    @Test func updatesHorizontalPositionWithoutReplacingContent() throws {
        let tabBarController = makeTestTabBarController()
        let coordinator = OverlayTabBarAccessoryCoordinator()
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        coordinator.setAccessoryView(
            contentView,
            position: .center,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()

        let hostView = try #require(contentView.superview)
        let safeAreaFrame = tabBarController.view.safeAreaLayoutGuide.layoutFrame
        #expect(abs(hostView.frame.midX - safeAreaFrame.midX) <= 0.5)

        coordinator.setAccessoryView(
            contentView,
            position: .leading,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()

        #expect(contentView.superview === hostView)
        #expect(abs(hostView.frame.minX - (safeAreaFrame.minX + 8)) <= 0.5)
    }

    @Test func animatedVisibleUpdateDoesNotFadeExistingHost() throws {
        let tabBarController = makeTestTabBarController()
        let coordinator = OverlayTabBarAccessoryCoordinator()
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()

        let hostView = try #require(contentView.superview)
        #expect(hostView.alpha == 1)

        coordinator.setAccessoryView(
            contentView,
            position: .leading,
            animated: true,
            in: tabBarController
        )

        #expect(hostView.alpha == 1)
        #expect(hostView.layer.animation(forKey: "opacity") == nil)
    }

    @Test func sameViewButtonCountTransitionsAnimateHostGeometryInPlace() throws {
        let tabBarController = makeEmptyTestTabBarController()
        addTestTabBarButton(height: 48, to: tabBarController)
        let coordinator = OverlayTabBarAccessoryCoordinator(
            isReduceMotionEnabled: { false }
        )
        TabBarAccessoryViewLifecycleHooks.register(coordinator, for: tabBarController)
        let plusButton = makeSystemMenuButton()
        let inspectorButton = makeSystemMenuButton()
        let otherAccountButton = makeSystemMenuButton()
        let stackView = UIStackView(arrangedSubviews: [plusButton])
        stackView.axis = .horizontal
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false

        coordinator.setAccessoryView(
            stackView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()

        let installedHost = try #require(stackView.superview)
        let installedConstraintIDs = constraintIDs(in: [tabBarController.view, installedHost])

        func transition(animated: Bool) -> CGSize {
            coordinator.setAccessoryView(
                stackView,
                position: .trailing,
                animated: animated,
                in: tabBarController
            )
            tabBarController.view.layoutIfNeeded()

            #expect(stackView.superview === installedHost)
            #expect(constraintIDs(in: [tabBarController.view, installedHost]) == installedConstraintIDs)
            if animated {
                #expect(installedHost.layer.animationKeys()?.isEmpty == false)
            }
            return installedHost.bounds.size
        }

        let oneButtonSize = installedHost.bounds.size
        #expect(abs(oneButtonSize.width - oneButtonSize.height) <= 0.5)

        stackView.insertArrangedSubview(inspectorButton, at: 0)
        let twoButtonSize = transition(animated: true)
        #expect(twoButtonSize.width > oneButtonSize.width)

        stackView.insertArrangedSubview(otherAccountButton, at: 0)
        let threeButtonSize = transition(animated: true)
        #expect(threeButtonSize.width > twoButtonSize.width)

        stackView.removeArrangedSubview(otherAccountButton)
        otherAccountButton.removeFromSuperview()
        let returnedTwoButtonSize = transition(animated: true)
        #expect(abs(returnedTwoButtonSize.width - twoButtonSize.width) <= 0.5)

        stackView.removeArrangedSubview(inspectorButton)
        inspectorButton.removeFromSuperview()
        let returnedOneButtonSize = transition(animated: true)
        #expect(abs(returnedOneButtonSize.width - oneButtonSize.width) <= 0.5)

        _ = transition(animated: false)
        #expect(stackView.arrangedSubviews == [plusButton])
    }

    @Test func sameViewGeometryUpdateDisablesAnimationForReduceMotion() throws {
        let tabBarController = makeEmptyTestTabBarController()
        addTestTabBarButton(height: 48, to: tabBarController)
        let coordinator = OverlayTabBarAccessoryCoordinator(
            isReduceMotionEnabled: { true }
        )
        let stackView = makeSystemButtonStack(buttonCount: 1)

        coordinator.setAccessoryView(
            stackView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()

        let installedHost = try #require(stackView.superview)
        let initialSize = installedHost.bounds.size
        stackView.insertArrangedSubview(makeSystemMenuButton(), at: 0)
        coordinator.setAccessoryView(
            stackView,
            position: .trailing,
            animated: true,
            in: tabBarController
        )

        #expect(stackView.superview === installedHost)
        #expect(installedHost.bounds.width > initialSize.width)
        #expect(installedHost.layer.animationKeys()?.isEmpty ?? true)
    }

    @Test func hiddenAccessoryDoesNotUpdatePositionUntilShownAgain() throws {
        let tabBarController = makeTestTabBarController()
        let coordinator = OverlayTabBarAccessoryCoordinator()
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        coordinator.setHidden(true, animated: false, in: tabBarController)
        tabBarController.view.layoutIfNeeded()

        let hostView = try #require(contentView.superview)
        let hiddenFrame = hostView.frame

        coordinator.setAccessoryView(
            contentView,
            position: .leading,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()

        let safeAreaFrame = tabBarController.view.safeAreaLayoutGuide.layoutFrame
        #expect(hiddenFrame != hostView.frame)
        #expect(abs(hostView.frame.minX - (safeAreaFrame.minX + 8)) <= 0.5)
        #expect(hostView.isHidden == false)
        #expect(coordinator.isHidden == false)
    }

    @Test func followsSafeAreaWhenTabBarIsHidden() throws {
        let tabBarController = makeTestTabBarController()
        let coordinator = OverlayTabBarAccessoryCoordinator()
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()
        let visibleBottomY = try #require(contentView.superview).frame.maxY

        coordinator.tabBarVisibilityDidChange(
            hidden: true,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()

        let hostView = try #require(contentView.superview)
        let expectedBottomY = tabBarController.view.safeAreaLayoutGuide.layoutFrame.maxY - 8

        #expect(abs(hostView.frame.maxY - expectedBottomY) <= 0.5)
        #expect(hostView.frame.maxY > visibleBottomY)
    }

    @Test func installsRevealHitAreaBehindAccessoryWhenTabBarIsHidden() throws {
        let tabBarController = makeTestTabBarController()
        let coordinator = OverlayTabBarAccessoryCoordinator()
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()
        let tabBarFrame = tabBarController.tabBar.convert(
            tabBarController.tabBar.bounds,
            to: tabBarController.view
        )

        coordinator.tabBarVisibilityDidChange(
            hidden: true,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()

        let hostView = try #require(contentView.superview)
        let hitAreaView = try #require(revealHitAreaViews(in: tabBarController).first)
        let expectedFrame = CGRect(
            x: tabBarController.view.bounds.minX,
            y: tabBarFrame.minY,
            width: tabBarController.view.bounds.width,
            height: tabBarController.view.bounds.maxY - tabBarFrame.minY
        )
        let accessoryPoint = tabBarController.view.convert(
            CGPoint(x: hostView.bounds.midX, y: hostView.bounds.midY),
            from: hostView
        )
        let revealPoint = CGPoint(x: hitAreaView.frame.minX + 4, y: hitAreaView.frame.midY)

        #expect(abs(hitAreaView.frame.minY - expectedFrame.minY) <= 0.5)
        #expect(abs(hitAreaView.frame.height - expectedFrame.height) <= 0.5)
        #expect(tabBarController.view.hitTest(accessoryPoint, with: nil) !== hitAreaView)
        #expect(tabBarController.view.hitTest(revealPoint, with: nil) === hitAreaView)
        #expect(hitAreaView.gestureRecognizers?.contains { $0 is UITapGestureRecognizer } == true)
        #expect(hitAreaView.gestureRecognizers?.contains { $0 is UILongPressGestureRecognizer } == true)

        coordinator.tabBarVisibilityDidChange(
            hidden: false,
            animated: false,
            in: tabBarController
        )

        #expect(revealHitAreaViews(in: tabBarController).isEmpty)
    }

    @Test func removesRevealHitAreaWhenAccessoryIsHidden() throws {
        let tabBarController = makeTestTabBarController()
        let coordinator = OverlayTabBarAccessoryCoordinator()
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        coordinator.tabBarVisibilityDidChange(
            hidden: true,
            animated: false,
            in: tabBarController
        )

        #expect(revealHitAreaViews(in: tabBarController).isEmpty == false)

        coordinator.setHidden(true, animated: false, in: tabBarController)

        #expect(revealHitAreaViews(in: tabBarController).isEmpty)
    }

    @Test func revealHitAreaUsesCurrentBoundsAfterHiddenResize() throws {
        let tabBarController = makeTestTabBarController()
        let coordinator = OverlayTabBarAccessoryCoordinator()
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()
        let visibleTabBarHeight = tabBarController.tabBar.convert(
            tabBarController.tabBar.bounds,
            to: tabBarController.view
        ).height

        coordinator.tabBarVisibilityDidChange(
            hidden: true,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.frame = CGRect(origin: .zero, size: CGSize(width: 844, height: 390))
        let hiddenTabBarHeight = visibleTabBarHeight + 12
        tabBarController.tabBar.bounds = CGRect(
            origin: tabBarController.tabBar.bounds.origin,
            size: CGSize(width: tabBarController.tabBar.bounds.width, height: hiddenTabBarHeight)
        )
        coordinator.update(in: tabBarController)
        tabBarController.view.layoutIfNeeded()

        let hitAreaView = try #require(revealHitAreaViews(in: tabBarController).first)

        #expect(abs(hitAreaView.frame.minY - (tabBarController.view.bounds.maxY - hiddenTabBarHeight)) <= 0.5)
        #expect(abs(hitAreaView.frame.maxY - tabBarController.view.bounds.maxY) <= 0.5)
    }

    @Test func infersHiddenTabBarWhenFirstLayoutSeesOffscreenTabBar() throws {
        let tabBarController = makeTestTabBarController()
        tabBarController.tabBar.frame.origin.y = tabBarController.view.bounds.maxY + 100
        let coordinator = OverlayTabBarAccessoryCoordinator()
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()

        let hostView = try #require(contentView.superview)
        let expectedBottomY = tabBarController.view.safeAreaLayoutGuide.layoutFrame.maxY - 8

        #expect(abs(hostView.frame.maxY - expectedBottomY) <= 0.5)
        #expect(revealHitAreaViews(in: tabBarController).isEmpty == false)
    }

    @Test func directHiddenTabBarStateOverridesCachedVisiblePosition() throws {
        let tabBarController = makeTestTabBarController()
        let coordinator = OverlayTabBarAccessoryCoordinator()
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()
        let hostView = try #require(contentView.superview)
        let visibleBottomY = hostView.frame.maxY

        tabBarController.tabBar.isHidden = true
        coordinator.update(in: tabBarController)
        tabBarController.view.layoutIfNeeded()

        let expectedBottomY = tabBarController.view.safeAreaLayoutGuide.layoutFrame.maxY - 8
        #expect(abs(hostView.frame.maxY - expectedBottomY) <= 0.5)
        #expect(hostView.frame.maxY > visibleBottomY)
        #expect(revealHitAreaViews(in: tabBarController).isEmpty == false)
    }

    @Test func keepsLastVisibleTabBarPositionWhenTabBarFrameLeavesViewBeforeHiddenCallback() throws {
        let tabBarController = makeTestTabBarController()
        let coordinator = OverlayTabBarAccessoryCoordinator()
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()
        let visibleBottomY = try #require(contentView.superview).frame.maxY

        tabBarController.tabBar.frame.origin.y = tabBarController.view.bounds.maxY + 100
        coordinator.update(in: tabBarController)
        tabBarController.view.layoutIfNeeded()

        #expect(abs((contentView.superview?.frame.maxY ?? 0) - visibleBottomY) <= 0.5)
    }

    @Test func tabBarVisibilityChangeIsIgnoredWhileAccessoryIsHidden() throws {
        let tabBarController = makeTestTabBarController()
        let coordinator = OverlayTabBarAccessoryCoordinator()
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()
        let hostView = try #require(contentView.superview)

        coordinator.setHidden(true, animated: false, in: tabBarController)
        let hiddenFrame = hostView.frame

        coordinator.tabBarVisibilityDidChange(
            hidden: true,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()

        #expect(hostView.frame == hiddenFrame)
        #expect(hostView.isHidden == true)
        #expect(coordinator.isHidden == true)
    }

    @Test func remembersHiddenTabBarBeforeContentIsInstalled() throws {
        let tabBarController = makeTestTabBarController()
        let coordinator = OverlayTabBarAccessoryCoordinator()
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        coordinator.tabBarVisibilityDidChange(
            hidden: true,
            animated: false,
            in: tabBarController
        )
        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()

        let hostView = try #require(contentView.superview)
        let expectedBottomY = tabBarController.view.safeAreaLayoutGuide.layoutFrame.maxY - 8

        #expect(abs(hostView.frame.maxY - expectedBottomY) <= 0.5)
    }

    @Test func remembersHiddenTabBarWhileAccessoryIsHidden() throws {
        let tabBarController = makeTestTabBarController()
        let coordinator = OverlayTabBarAccessoryCoordinator()
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        coordinator.setHidden(true, animated: false, in: tabBarController)
        coordinator.tabBarVisibilityDidChange(
            hidden: true,
            animated: false,
            in: tabBarController
        )
        coordinator.setHidden(false, animated: false, in: tabBarController)
        tabBarController.view.layoutIfNeeded()

        let hostView = try #require(contentView.superview)
        let expectedBottomY = tabBarController.view.safeAreaLayoutGuide.layoutFrame.maxY - 8

        #expect(abs(hostView.frame.maxY - expectedBottomY) <= 0.5)
        #expect(hostView.isHidden == false)
    }

    @Test func appliesAccessoryInsetToSelectedViewControllerAdditionalSafeAreaInsets() throws {
        let selectedViewController = UIViewController()
        selectedViewController.additionalSafeAreaInsets.bottom = 12
        let tabBarController = makeTestTabBarController(viewControllers: [selectedViewController])
        let coordinator = OverlayTabBarAccessoryCoordinator()
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()

        let hostView = try #require(contentView.superview)
        let expectedBottomInset = 12 + hostView.bounds.height + 8

        #expect(abs(selectedViewController.additionalSafeAreaInsets.bottom - expectedBottomInset) <= 0.5)
    }

    @Test func restoresManagedAdditionalSafeAreaInsetWhenHiddenAndRemoved() throws {
        let selectedViewController = UIViewController()
        selectedViewController.additionalSafeAreaInsets.bottom = 12
        let tabBarController = makeTestTabBarController(viewControllers: [selectedViewController])
        let coordinator = OverlayTabBarAccessoryCoordinator()
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()

        let hostView = try #require(contentView.superview)
        let expectedBottomInset = 12 + hostView.bounds.height + 8
        #expect(abs(selectedViewController.additionalSafeAreaInsets.bottom - expectedBottomInset) <= 0.5)

        coordinator.setHidden(true, animated: false, in: tabBarController)
        #expect(abs(selectedViewController.additionalSafeAreaInsets.bottom - 12) <= 0.5)

        coordinator.setHidden(false, animated: false, in: tabBarController)
        tabBarController.view.layoutIfNeeded()
        #expect(abs(selectedViewController.additionalSafeAreaInsets.bottom - expectedBottomInset) <= 0.5)

        coordinator.setAccessoryView(nil, position: .trailing, animated: false, in: tabBarController)
        #expect(abs(selectedViewController.additionalSafeAreaInsets.bottom - 12) <= 0.5)
    }

    @Test func movesManagedAdditionalSafeAreaInsetWhenSelectedTabChanges() throws {
        let firstViewController = UIViewController()
        firstViewController.additionalSafeAreaInsets.bottom = 5
        let secondViewController = UIViewController()
        secondViewController.additionalSafeAreaInsets.bottom = 7
        let tabBarController = makeTestTabBarController(
            viewControllers: [firstViewController, secondViewController]
        )
        let coordinator = OverlayTabBarAccessoryCoordinator()
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()

        let hostView = try #require(contentView.superview)
        let managedBottomInset = hostView.bounds.height + 8
        #expect(abs(firstViewController.additionalSafeAreaInsets.bottom - (5 + managedBottomInset)) <= 0.5)
        #expect(abs(secondViewController.additionalSafeAreaInsets.bottom - 7) <= 0.5)

        tabBarController.selectedIndex = 1
        coordinator.update(in: tabBarController)
        tabBarController.view.layoutIfNeeded()

        #expect(abs(firstViewController.additionalSafeAreaInsets.bottom - 5) <= 0.5)
        #expect(abs(secondViewController.additionalSafeAreaInsets.bottom - (7 + managedBottomInset)) <= 0.5)

        coordinator.setAccessoryView(nil, position: .trailing, animated: false, in: tabBarController)
        #expect(abs(secondViewController.additionalSafeAreaInsets.bottom - 7) <= 0.5)
    }

    @Test func tabBarVisibilityChangeKeepsManagedInsetLimitedToAccessoryOnly() throws {
        let selectedViewController = UIViewController()
        let tabBarController = makeTestTabBarController(viewControllers: [selectedViewController])
        let coordinator = OverlayTabBarAccessoryCoordinator()
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()

        let visibleBottomInset = selectedViewController.additionalSafeAreaInsets.bottom

        coordinator.tabBarVisibilityDidChange(hidden: true, animated: false, in: tabBarController)
        tabBarController.view.layoutIfNeeded()
        #expect(abs(selectedViewController.additionalSafeAreaInsets.bottom - visibleBottomInset) <= 0.5)

        coordinator.tabBarVisibilityDidChange(hidden: false, animated: false, in: tabBarController)
        tabBarController.view.layoutIfNeeded()
        #expect(abs(selectedViewController.additionalSafeAreaInsets.bottom - visibleBottomInset) <= 0.5)
    }

    @Test func usesTabBarButtonHeightAndExpandsToContentAspectRatio() throws {
        let tabBarController = makeEmptyTestTabBarController()
        addTestTabBarButton(height: 64, to: tabBarController)
        let coordinator = OverlayTabBarAccessoryCoordinator()
        let squareContentView = FixedSizeView(size: CGSize(width: 44, height: 44))
        let wideContentView = FixedSizeView(size: CGSize(width: 96, height: 48))

        coordinator.setAccessoryView(
            squareContentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()

        #expect(try #require(squareContentView.superview).bounds.size == CGSize(width: 64, height: 64))

        coordinator.setAccessoryView(
            wideContentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()

        #expect(try #require(wideContentView.superview).bounds.size == CGSize(width: 128, height: 64))
    }

    @Test func intrinsicOnlyContentPreservesAspectRatio() throws {
        let tabBarController = makeEmptyTestTabBarController()
        addTestTabBarButton(height: 64, to: tabBarController)
        let coordinator = OverlayTabBarAccessoryCoordinator()
        let contentView = IntrinsicOnlySizeView(
            size: CGSize(width: 96, height: 48)
        )

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()

        #expect(
            try #require(contentView.superview).bounds.size
                == CGSize(width: 128, height: 64)
        )
    }

    @Test func usesTabBarButtonHeightForContentWithoutPreferredSize() throws {
        let tabBarController = makeEmptyTestTabBarController()
        addTestTabBarButton(height: 64, to: tabBarController)
        let coordinator = OverlayTabBarAccessoryCoordinator()
        let contentView = NoIntrinsicSizeView()

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()

        #expect(try #require(contentView.superview).bounds.size == CGSize(width: 64, height: 64))
    }

    @Test func ignoresHiddenAndTransparentTabBarButtonHeightCandidates() throws {
        let tabBarController = makeEmptyTestTabBarController()
        addTestTabBarButton(height: 96, isHidden: true, to: tabBarController)
        addTestTabBarButton(height: 88, alpha: 0, to: tabBarController)
        addTestTabBarButton(height: 64, to: tabBarController)
        let coordinator = OverlayTabBarAccessoryCoordinator()
        let contentView = NoIntrinsicSizeView()

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()

        #expect(try #require(contentView.superview).bounds.size == CGSize(width: 64, height: 64))
    }

    @Test func ignoresLookalikeTabBarButtonClassNames() throws {
        let tabBarController = makeEmptyTestTabBarController()
        let lookalikeButton = LookalikeTabBarButton(frame: CGRect(x: 0, y: 0, width: 80, height: 96))
        tabBarController.tabBar.addSubview(lookalikeButton)
        addTestTabBarButton(height: 64, to: tabBarController)
        let coordinator = OverlayTabBarAccessoryCoordinator()
        let contentView = NoIntrinsicSizeView()

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()

        #expect(try #require(contentView.superview).bounds.size == CGSize(width: 64, height: 64))
    }

    @Test func fallsBackToFallbackSquareSizeWithoutPreferredSizeOrTabBarButtons() throws {
        let tabBarController = makeEmptyTestTabBarController()
        let coordinator = OverlayTabBarAccessoryCoordinator()
        let contentView = NoIntrinsicSizeView()

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()

        #expect(try #require(contentView.superview).bounds.size == CGSize(width: 48, height: 48))
    }

    @Test func usesFallbackMinimumForSmallIntrinsicHeightWithoutTabBarButtons() throws {
        let tabBarController = makeEmptyTestTabBarController()
        let coordinator = OverlayTabBarAccessoryCoordinator()
        let contentView = FixedSizeView(size: CGSize(width: 24, height: 24))

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()

        #expect(try #require(contentView.superview).bounds.size == CGSize(width: 48, height: 48))
    }

    @Test func clampsWidthToSafeAreaMargins() throws {
        let tabBarController = makeTestTabBarController()
        let coordinator = OverlayTabBarAccessoryCoordinator()
        let contentView = FixedSizeView(size: CGSize(width: 1000, height: 48))

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()

        let hostView = try #require(contentView.superview)
        let safeAreaFrame = tabBarController.view.safeAreaLayoutGuide.layoutFrame

        #expect(abs(hostView.bounds.width - (safeAreaFrame.width - 16)) <= 0.5)
        #expect(abs(hostView.frame.maxX - (safeAreaFrame.maxX - 8)) <= 0.5)
    }

    @Test func updateRefreshesSizeForExistingContentView() throws {
        let tabBarController = makeEmptyTestTabBarController()
        let tabBarButton = addTestTabBarButton(height: 64, to: tabBarController)
        let coordinator = OverlayTabBarAccessoryCoordinator()
        let contentView = MutableSizeView(size: CGSize(width: 44, height: 44))

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()
        let hostView = try #require(contentView.superview)
        #expect(hostView.bounds.size == CGSize(width: 64, height: 64))

        contentView.size = CGSize(width: 120, height: 80)
        coordinator.update(in: tabBarController)
        tabBarController.view.layoutIfNeeded()

        #expect(contentView.superview === hostView)
        #expect(hostView.bounds.size == CGSize(width: 96, height: 64))

        tabBarButton.frame.size.height = 32
        coordinator.update(in: tabBarController)
        tabBarController.view.layoutIfNeeded()

        #expect(hostView.bounds.size == CGSize(width: 48, height: 32))
    }

    @Test func appliesTabBarAppearanceBackgroundToHost() throws {
        let tabBarController = makeTestTabBarController()
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)
        appearance.backgroundColor = UIColor.systemRed.withAlphaComponent(0.35)
        tabBarController.tabBar.standardAppearance = appearance

        let coordinator = OverlayTabBarAccessoryCoordinator()
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()

        let hostView = try #require(contentView.superview)
        let effectView = hostView.subviews.compactMap { $0 as? UIVisualEffectView }.first
        let backgroundColorView = hostView.subviews.first { !($0 is UIVisualEffectView) }

        #expect(effectView?.effect != nil)
        #expect(backgroundColorView?.backgroundColor?.isEqual(appearance.backgroundColor) == true)
        #expect(hostView.clipsToBounds == true)
        #expect(abs(hostView.layer.cornerRadius - hostView.bounds.height / 2) <= 0.5)
    }

    @Test func repeatedUpdatesReuseInstalledConstraints() throws {
        let tabBarController = makeTestTabBarController()
        let coordinator = OverlayTabBarAccessoryCoordinator()
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()

        let hostView = try #require(contentView.superview)
        let initialConstraintIDs = constraintIDs(in: [tabBarController.view, hostView])

        for _ in 0..<10 {
            coordinator.update(in: tabBarController)
            tabBarController.view.layoutIfNeeded()
        }

        #expect(constraintIDs(in: [tabBarController.view, hostView]) == initialConstraintIDs)
    }

    @Test func replacesContentViewWithoutLeavingOldSuperview() throws {
        let tabBarController = makeEmptyTestTabBarController()
        addTestTabBarButton(height: 64, to: tabBarController)
        let coordinator = OverlayTabBarAccessoryCoordinator()
        let firstView = FixedSizeView(size: CGSize(width: 44, height: 44))
        let secondView = FixedSizeView(size: CGSize(width: 88, height: 44))

        coordinator.setAccessoryView(
            firstView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        coordinator.setAccessoryView(
            secondView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()

        #expect(firstView.superview == nil)
        #expect(firstView.translatesAutoresizingMaskIntoConstraints == true)
        #expect(try #require(secondView.superview).bounds.size == CGSize(width: 128, height: 64))
        #expect(constraintsReferencing(firstView, in: [tabBarController.view, try #require(secondView.superview)]).isEmpty)
    }

    @Test func restoresOriginalAutoresizingMaskValueWhenItWasAlreadyDisabled() {
        let tabBarController = makeTestTabBarController()
        let coordinator = OverlayTabBarAccessoryCoordinator()
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))
        contentView.translatesAutoresizingMaskIntoConstraints = false

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        coordinator.setAccessoryView(nil, position: .trailing, animated: false, in: tabBarController)

        #expect(contentView.superview == nil)
        #expect(contentView.translatesAutoresizingMaskIntoConstraints == false)
    }

    @Test func setNilRemovesHostAndConstraints() throws {
        let tabBarController = makeTestTabBarController()
        let coordinator = OverlayTabBarAccessoryCoordinator()
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()

        let hostView = try #require(contentView.superview)
        let installedConstraintIDs = constraintIDs(in: [tabBarController.view, hostView])
        #expect(installedConstraintIDs.isEmpty == false)

        coordinator.setAccessoryView(nil, position: .trailing, animated: false, in: tabBarController)

        #expect(contentView.superview == nil)
        #expect(hostView.superview == nil)
        #expect(contentView.translatesAutoresizingMaskIntoConstraints == true)
        #expect(coordinator.isHidden == false)
        #expect(constraintsReferencing(hostView, in: [tabBarController.view]).isEmpty)
        #expect(constraintsReferencing(contentView, in: [hostView]).isEmpty)
    }

    @Test func animatedHideAndShowKeepHostForReuse() async throws {
        let tabBarController = makeTestTabBarController()
        let coordinator = OverlayTabBarAccessoryCoordinator()
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()
        let hostView = try #require(contentView.superview)

        coordinator.setHidden(true, animated: true, in: tabBarController)
        coordinator.setHidden(false, animated: true, in: tabBarController)
        try await Task.sleep(for: .milliseconds(350))

        #expect(contentView.superview === hostView)
        #expect(coordinator.isHidden == false)
        #expect(hostView.isHidden == false)
        #expect(abs(hostView.alpha - 1) <= 0.01)
    }

    @Test func animatedRemovalCompletionDoesNotClearReplacementContent() async throws {
        let tabBarController = makeTestTabBarController()
        let coordinator = OverlayTabBarAccessoryCoordinator()
        let firstView = FixedSizeView(size: CGSize(width: 44, height: 44))
        let secondView = FixedSizeView(size: CGSize(width: 88, height: 44))

        coordinator.setAccessoryView(
            firstView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        coordinator.setAccessoryView(nil, position: .trailing, animated: true, in: tabBarController)
        coordinator.setAccessoryView(
            secondView,
            position: .leading,
            animated: false,
            in: tabBarController
        )
        try await Task.sleep(for: .milliseconds(350))
        tabBarController.view.layoutIfNeeded()

        let hostView = try #require(secondView.superview)
        let safeAreaFrame = tabBarController.view.safeAreaLayoutGuide.layoutFrame

        #expect(firstView.superview == nil)
        #expect(hostView.superview === tabBarController.view)
        #expect(abs(hostView.frame.minX - (safeAreaFrame.minX + 8)) <= 0.5)
        #expect(coordinator.isHidden == false)
    }

    private func makeSystemMenuButton() -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "plus")
        configuration.buttonSize = .large
        configuration.cornerStyle = .capsule

        let button = UIButton(configuration: configuration)
        button.menu = UIMenu(children: [
            UIAction(title: "Action") { _ in }
        ])
        button.showsMenuAsPrimaryAction = true
        return button
    }

    private func makeSystemButtonStack(buttonCount: Int) -> UIStackView {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 4
        for _ in 0..<buttonCount {
            stackView.addArrangedSubview(makeSystemMenuButton())
        }
        return stackView
    }
}
