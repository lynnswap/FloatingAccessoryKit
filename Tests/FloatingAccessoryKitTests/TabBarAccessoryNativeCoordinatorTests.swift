import Testing
import UIKit
@testable import FloatingAccessoryKit

@MainActor
@Suite
struct TabBarAccessoryNativeCoordinatorTests {
    @Test func setHiddenWithoutContentIsNoOp() {
        guard #available(iOS 26.0, *) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let coordinator = TabBarAccessoryCoordinator()

        coordinator.setHidden(true, animated: false, in: tabBarController)

        #expect(coordinator.isHidden == false)
        #expect(tabBarController.bottomAccessory == nil)
    }

    @Test func setAccessoryViewInstallsBottomAccessory() {
        guard #available(iOS 26.0, *) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let coordinator = TabBarAccessoryCoordinator()
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )

        #expect(tabBarController.bottomAccessory != nil)
        #expect(coordinator.isHidden == false)
    }

    @Test func setAccessoryViewUsesFiniteInitialSizeForContentWithoutIntrinsicSize() throws {
        guard #available(iOS 26.0, *) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let coordinator = TabBarAccessoryCoordinator()
        let contentView = NoIntrinsicSizeView()

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()
        coordinator.update(in: tabBarController)

        let width = try #require(contentView.constraints.first { $0.firstAttribute == .width })
        let height = try #require(contentView.constraints.first { $0.firstAttribute == .height })

        #expect(width.constant.isFinite)
        #expect(width.constant > 0)
        #expect(height.constant.isFinite)
        #expect(height.constant > 0)
    }

    @Test func setHiddenRemovesAndRestoresBottomAccessory() {
        guard #available(iOS 26.0, *) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let coordinator = TabBarAccessoryCoordinator()
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        let bottomAccessory = tabBarController.bottomAccessory

        coordinator.setHidden(true, animated: false, in: tabBarController)
        #expect(coordinator.isHidden == true)
        #expect(tabBarController.bottomAccessory == nil)

        coordinator.setHidden(false, animated: false, in: tabBarController)
        #expect(coordinator.isHidden == false)
        #expect(tabBarController.bottomAccessory === bottomAccessory)
    }

    @Test func setAccessoryViewNilClearsBottomAccessoryAndHiddenState() {
        guard #available(iOS 26.0, *) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let coordinator = TabBarAccessoryCoordinator()
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        coordinator.setHidden(true, animated: false, in: tabBarController)
        coordinator.setAccessoryView(nil, position: .trailing, animated: false, in: tabBarController)

        #expect(tabBarController.bottomAccessory == nil)
        #expect(coordinator.isHidden == false)
    }

    @Test func replacingContentViewReplacesBottomAccessory() {
        guard #available(iOS 26.0, *) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let coordinator = TabBarAccessoryCoordinator()
        let firstView = FixedSizeView(size: CGSize(width: 44, height: 44))
        let secondView = FixedSizeView(size: CGSize(width: 88, height: 44))

        coordinator.setAccessoryView(
            firstView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        let firstAccessory = tabBarController.bottomAccessory

        coordinator.setAccessoryView(
            secondView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )

        #expect(tabBarController.bottomAccessory != nil)
        #expect(tabBarController.bottomAccessory !== firstAccessory)
        #expect(coordinator.isHidden == false)
    }
}
