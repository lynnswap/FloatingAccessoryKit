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
}
