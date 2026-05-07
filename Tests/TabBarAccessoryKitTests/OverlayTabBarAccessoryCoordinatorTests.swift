import Testing
import UIKit
@testable import TabBarAccessoryKit

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

    @Test func usesMinimumSizeAndExpandsToContentAspectRatio() throws {
        let tabBarController = makeTestTabBarController()
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

        #expect(try #require(squareContentView.superview).bounds.size == CGSize(width: 48, height: 48))

        coordinator.setAccessoryView(
            wideContentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()

        #expect(try #require(wideContentView.superview).bounds.size == CGSize(width: 96, height: 48))
    }

    @Test func fallsBackToMinimumSquareSizeForContentWithoutPreferredSize() throws {
        let tabBarController = makeTestTabBarController()
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
        let tabBarController = makeTestTabBarController()
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
        #expect(hostView.bounds.size == CGSize(width: 48, height: 48))

        contentView.size = CGSize(width: 120, height: 60)
        coordinator.update(in: tabBarController)
        tabBarController.view.layoutIfNeeded()

        #expect(contentView.superview === hostView)
        #expect(hostView.bounds.size == CGSize(width: 120, height: 60))
    }

    @Test func usesTabBarAppearanceBackground() throws {
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
        coordinator.setAccessoryView(
            secondView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()

        #expect(firstView.superview == nil)
        #expect(firstView.translatesAutoresizingMaskIntoConstraints == true)
        #expect(try #require(secondView.superview).bounds.size == CGSize(width: 96, height: 48))
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
