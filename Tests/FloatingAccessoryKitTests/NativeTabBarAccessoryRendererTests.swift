import Testing
import UIKit
@testable import FloatingAccessoryKit

@MainActor
@Suite
struct NativeTabBarAccessoryRendererTests {
    @Test func hiddenRequestPersistsWithoutContent() {
        guard #available(iOS 26.0, *) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let renderer = AccessoryRendererHarness(renderer: NativeTabBarAccessoryRenderer())

        renderer.setHidden(true, animated: false, in: tabBarController)

        #expect(renderer.isHidden)
        #expect(tabBarController.bottomAccessory == nil)
    }

    @Test func installingContentUsesNativeBottomAccessory() throws {
        guard #available(iOS 26.0, *) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let renderer = AccessoryRendererHarness(renderer: NativeTabBarAccessoryRenderer())
        let contentView = FixedSizeView(size: CGSize(width: 88, height: 44))

        renderer.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()
        renderer.update(in: tabBarController)

        let contentHost = try #require(contentView.superview as? AccessoryContentHostView)
        #expect(tabBarController.bottomAccessory != nil)
        #expect(contentHost.superview != nil)
        #expect(renderer.isHidden == false)
    }

    @Test func contentWithoutPreferredSizeReceivesFiniteManagedSize() throws {
        guard #available(iOS 26.0, *) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let renderer = AccessoryRendererHarness(renderer: NativeTabBarAccessoryRenderer())
        let contentView = NoIntrinsicSizeView()

        renderer.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()
        renderer.update(in: tabBarController)

        let contentHost = try #require(contentView.superview as? AccessoryContentHostView)
        let size = try managedSize(of: contentHost)
        #expect(size.width.isFinite && size.width > 0)
        #expect(size.height.isFinite && size.height > 0)
    }

    @Test func layoutRemeasuresChangedContentWithoutResubmission() throws {
        guard #available(iOS 26.0, *) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let controller = tabBarController.floatingAccessoryController
        let contentView = MutableSizeView(size: CGSize(width: 44, height: 44))

        controller.setContentView(contentView)
        tabBarController.view.layoutIfNeeded()

        let contentHost = try #require(contentView.superview as? AccessoryContentHostView)
        let initialSize = try managedSize(of: contentHost)

        contentView.size = CGSize(width: 132, height: 44)
        contentHost.setNeedsLayout()
        contentHost.layoutIfNeeded()
        tabBarController.view.layoutIfNeeded()

        let updatedSize = try managedSize(of: contentHost)
        #expect(updatedSize.width > initialSize.width)
        #expect(updatedSize.height == initialSize.height)
        #expect(controller.contentView === contentView)
    }

    @Test func changingPositionPreservesNativeAccessoryIdentity() {
        guard #available(iOS 26.0, *) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let controller = tabBarController.floatingAccessoryController
        let contentView = FixedSizeView(size: CGSize(width: 88, height: 44))

        controller.setContentView(contentView, position: .trailing)
        tabBarController.view.layoutIfNeeded()
        let installedAccessory = tabBarController.bottomAccessory

        controller.setPosition(.leading)
        tabBarController.view.layoutIfNeeded()

        #expect(tabBarController.bottomAccessory === installedAccessory)
        #expect(controller.contentView === contentView)
    }

    @Test func hidingAndShowingReusesOwnedNativeAccessory() {
        guard #available(iOS 26.0, *) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let controller = tabBarController.floatingAccessoryController
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        controller.setContentView(contentView)
        let installedAccessory = tabBarController.bottomAccessory

        controller.setHidden(true)
        #expect(tabBarController.bottomAccessory == nil)
        #expect(controller.contentView === contentView)

        controller.setHidden(false)
        #expect(tabBarController.bottomAccessory === installedAccessory)
        #expect(contentView.superview != nil)
    }

    @Test func showingContentRebindsAfterDeferredNativeAttachment() async throws {
        guard #available(iOS 26.0, *) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let window = UIWindow(frame: tabBarController.view.bounds)
        window.rootViewController = tabBarController
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let nativeRenderer = NativeTabBarAccessoryRenderer()
        let renderer = AccessoryRendererHarness(renderer: nativeRenderer)
        nativeRenderer.contentSizeInvalidationHandler = { [weak renderer, weak tabBarController] _ in
            guard let renderer,
                  let tabBarController else {
                return
            }
            renderer.update(in: tabBarController)
        }
        let contentView = FixedSizeView(size: CGSize(width: 88, height: 44))

        renderer.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()
        renderer.update(in: tabBarController)
        renderer.setHidden(true, animated: false, in: tabBarController)
        renderer.setHidden(false, animated: false, in: tabBarController)
        await withCheckedContinuation { continuation in
            RunLoop.main.perform(inModes: [.common]) {
                continuation.resume()
            }
        }

        let contentHost = try #require(
            contentView.superview as? AccessoryContentHostView
        )
        let container = try #require(contentHost.superview)
        let managedCenteringConstraint = try #require(
            container.constraints.first { constraint in
                constraint.isActive
                    && constraint.firstItem === contentHost
                    && constraint.firstAttribute == .centerX
            }
        )
        #expect(managedCenteringConstraint.secondItem === container)
        #expect(try managedSize(of: contentHost).width > 0)
    }

    @Test func animatedRemovalDetachesConsumerSynchronously() {
        guard #available(iOS 26.0, *) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let controller = tabBarController.floatingAccessoryController
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        controller.setContentView(contentView)
        tabBarController.view.layoutIfNeeded()
        #expect(contentView.superview != nil)

        controller.removeContent(animated: true)

        #expect(contentView.superview == nil)
        #expect(controller.contentView == nil)
    }

    @Test func animatedRemovalDoesNotRemoveImmediatelyReparentedConsumer() {
        guard #available(iOS 26.0, *) else {
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

    @Test func foreignBottomAccessoryReplacementIsNotCleared() {
        guard #available(iOS 26.0, *) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let controller = tabBarController.floatingAccessoryController
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))
        let foreignAccessory = UITabAccessory(contentView: UIView())

        controller.setContentView(contentView)
        tabBarController.view.layoutIfNeeded()
        tabBarController.setBottomAccessory(foreignAccessory, animated: false)
        controller.removeContent(animated: false)

        #expect(tabBarController.bottomAccessory === foreignAccessory)
        #expect(controller.contentView == nil)
        #expect(contentView.superview == nil)
    }

    @Test func semanticUpdateDoesNotOverwriteForeignBottomAccessory() {
        guard #available(iOS 26.0, *) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let controller = tabBarController.floatingAccessoryController
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))
        let foreignAccessory = UITabAccessory(contentView: UIView())

        controller.setContentView(contentView)
        tabBarController.view.layoutIfNeeded()
        tabBarController.setBottomAccessory(foreignAccessory, animated: false)

        controller.setPosition(.center, animated: false)

        #expect(tabBarController.bottomAccessory === foreignAccessory)
        #expect(controller.contentView == nil)
        #expect(contentView.superview == nil)
    }

    @Test func showingHiddenContentDoesNotOverwriteForeignBottomAccessory() {
        guard #available(iOS 26.0, *) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let controller = tabBarController.floatingAccessoryController
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))
        let foreignAccessory = UITabAccessory(contentView: UIView())

        controller.setHidden(true)
        controller.setContentView(contentView)
        tabBarController.setBottomAccessory(foreignAccessory, animated: false)

        controller.setHidden(false)

        #expect(tabBarController.bottomAccessory === foreignAccessory)
        #expect(controller.contentView == nil)
        #expect(contentView.superview == nil)
    }

    @Test func installingHiddenContentPreservesForeignBottomAccessory() {
        guard #available(iOS 26.0, *) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let controller = tabBarController.floatingAccessoryController
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))
        let foreignAccessory = UITabAccessory(contentView: UIView())
        tabBarController.setBottomAccessory(foreignAccessory, animated: false)

        controller.setHidden(true)
        controller.setContentView(contentView)
        controller.setPosition(.center)

        #expect(tabBarController.bottomAccessory === foreignAccessory)
        #expect(controller.contentView === contentView)
        #expect(contentView.superview is AccessoryContentHostView)
    }

    @Test func updatingHiddenContentPreservesForeignBottomAccessory() {
        guard #available(iOS 26.0, *) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let renderer = AccessoryRendererHarness(renderer: NativeTabBarAccessoryRenderer())
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))
        let foreignAccessory = UITabAccessory(contentView: UIView())
        renderer.setHidden(true, animated: false, in: tabBarController)
        renderer.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.setBottomAccessory(foreignAccessory, animated: false)

        let result = renderer.update(in: tabBarController)

        #expect(result == .applied)
        #expect(tabBarController.bottomAccessory === foreignAccessory)
        #expect(contentView.superview is AccessoryContentHostView)
    }

    @Test func externalReparentingRelinquishesNativePresentationWithoutTouchingNewOwner() {
        guard #available(iOS 26.0, *) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let renderer = AccessoryRendererHarness(renderer: NativeTabBarAccessoryRenderer())
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))
        let newOwner = UIView()

        renderer.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()
        newOwner.addSubview(contentView)

        let result = renderer.update(in: tabBarController)

        #expect(result == .ownershipLost)
        #expect(contentView.superview === newOwner)
        #expect(tabBarController.bottomAccessory == nil)
    }

    @Test func replacingContentDetachesPreviousConsumer() {
        guard #available(iOS 26.0, *) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let controller = tabBarController.floatingAccessoryController
        let firstView = FixedSizeView(size: CGSize(width: 44, height: 44))
        let secondView = FixedSizeView(size: CGSize(width: 88, height: 44))

        controller.setContentView(firstView)
        controller.setContentView(secondView, animated: true)

        #expect(firstView.superview == nil)
        #expect(secondView.superview != nil)
        #expect(controller.contentView === secondView)
    }

    private func managedSize(of contentHost: UIView) throws -> CGSize {
        let width = try managedConstraint(
            of: contentHost,
            identifier: "FloatingAccessoryKit.contentWidth"
        )
        let height = try managedConstraint(
            of: contentHost,
            identifier: "FloatingAccessoryKit.contentHeight"
        )
        return CGSize(width: width.constant, height: height.constant)
    }

    private func managedConstraint(
        of view: UIView,
        identifier: String
    ) throws -> NSLayoutConstraint {
        try #require(view.constraints.first { constraint in
            constraint.identifier == identifier && constraint.isActive
        })
    }
}
