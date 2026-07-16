import Testing
import UIKit
@testable import FloatingAccessoryKit

@MainActor
@Suite(.serialized)
struct NativeAccessoryHelperTests {
    @Test func environmentObservationTracksContainerFrameChanges() {
        guard #available(iOS 26.0, *) else {
            return
        }

        let container = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 48))
        let contentHostView = AccessoryContentHostView(
            contentView: UIView(),
            preferredSizeDidChange: {}
        )
        let counter = NativeEnvironmentObservationCounter()
        let observation = NativeAccessoryEnvironmentObservation(
            container: container,
            contentHostView: contentHostView
        ) {
            counter.value += 1
        }

        container.frame.size.height = 32

        #expect(counter.value == 1)
        observation.invalidate()
    }

    @Test func environmentObservationTracksAccessoryTraitChanges() async {
        guard #available(iOS 26.0, *) else {
            return
        }

        let container = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 48))
        let contentHostView = AccessoryContentHostView(
            contentView: UIView(),
            preferredSizeDidChange: {}
        )
        let rootViewController = UIViewController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = rootViewController
        window.makeKeyAndVisible()
        rootViewController.view.addSubview(container)
        container.addSubview(contentHostView)
        rootViewController.view.layoutIfNeeded()

        let counter = NativeEnvironmentObservationCounter()
        let observation = NativeAccessoryEnvironmentObservation(
            container: container,
            contentHostView: contentHostView
        ) {
            counter.value += 1
        }

        container.traitOverrides.tabAccessoryEnvironment = .regular
        await Task.yield()

        #expect(counter.value == 1)
        observation.invalidate()
        window.isHidden = true
    }

    @Test func registeredContainerLimitsHitTestingToContent() {
        guard #available(iOS 26.0, *) else {
            return
        }

        let container = AccessoryContainerView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let button = UIButton(type: .system)
        button.frame = CGRect(x: 20, y: 20, width: 40, height: 40)
        container.addSubview(button)

        NativeAccessoryHitTesting.register(container: container, contentView: button)
        defer {
            NativeAccessoryHitTesting.unregister(container: container)
        }

        #expect(container.hitTest(CGPoint(x: 10, y: 10), with: nil) == nil)
        #expect(container.hitTest(CGPoint(x: 30, y: 30), with: nil) === button)
    }

    @Test func unregisteredContainerKeepsDefaultHitTesting() {
        guard #available(iOS 26.0, *) else {
            return
        }

        let container = AccessoryContainerView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let button = UIButton(type: .system)
        button.frame = CGRect(x: 20, y: 20, width: 40, height: 40)
        container.addSubview(button)

        NativeAccessoryHitTesting.register(container: container, contentView: button)
        NativeAccessoryHitTesting.unregister(container: container)

        #expect(container.hitTest(CGPoint(x: 10, y: 10), with: nil) === container)
        #expect(container.hitTest(CGPoint(x: 30, y: 30), with: nil) === button)
    }

    @Test func registeringOneContainerDoesNotAffectOtherContainersOfSameClass() {
        guard #available(iOS 26.0, *) else {
            return
        }

        let registeredContainer = AccessoryContainerView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let registeredButton = UIButton(type: .system)
        registeredButton.frame = CGRect(x: 20, y: 20, width: 40, height: 40)
        registeredContainer.addSubview(registeredButton)

        let unregisteredContainer = AccessoryContainerView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let unregisteredButton = UIButton(type: .system)
        unregisteredButton.frame = CGRect(x: 20, y: 20, width: 40, height: 40)
        unregisteredContainer.addSubview(unregisteredButton)

        NativeAccessoryHitTesting.register(container: registeredContainer, contentView: registeredButton)
        defer {
            NativeAccessoryHitTesting.unregister(container: registeredContainer)
        }

        #expect(registeredContainer.hitTest(CGPoint(x: 10, y: 10), with: nil) == nil)
        #expect(unregisteredContainer.hitTest(CGPoint(x: 10, y: 10), with: nil) === unregisteredContainer)
    }

    @Test func registeringPlainUIViewKeepsDefaultHitTesting() {
        guard #available(iOS 26.0, *) else {
            return
        }

        let container = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let button = UIButton(type: .system)
        button.frame = CGRect(x: 20, y: 20, width: 40, height: 40)
        container.addSubview(button)

        NativeAccessoryHitTesting.register(container: container, contentView: button)
        defer {
            NativeAccessoryHitTesting.unregister(container: container)
        }

        #expect(container.hitTest(CGPoint(x: 10, y: 10), with: nil) === container)
        #expect(container.hitTest(CGPoint(x: 30, y: 30), with: nil) === button)
    }

    @Test func sizingShrinksTrailingFrameToContentWidth() {
        guard #available(iOS 26.0, *) else {
            return
        }

        let host = AccessoryLayoutHostView(accessoryFrame: CGRect(x: 0, y: 0, width: 100, height: 48))
        let container = AccessoryContainerView(frame: host.accessoryFrame)
        let contentView = AccessoryContentView()
        host.bind(container)

        NativeAccessoryContainerLayout.register(
            container: container,
            contentView: contentView,
            position: .trailing
        )
        defer {
            NativeAccessoryContainerLayout.unregister(container: container)
        }

        NativeAccessoryContainerLayout.update(
            container: container,
            contentWidth: 44,
            position: .trailing
        )

        host.layoutIfNeeded()

        #expect(container.frame == CGRect(x: 56, y: 0, width: 44, height: 48))
    }

    @Test func sizingDefersElementMatchUntilContainerHasBounds() {
        guard #available(iOS 26.0, *) else {
            return
        }

        let host = AccessoryLayoutHostView(accessoryFrame: CGRect(x: 0, y: 0, width: 100, height: 48))
        let container = AccessoryContainerView(frame: .zero)
        let contentView = AccessoryContentView()
        host.bind(container)

        NativeAccessoryContainerLayout.register(
            container: container,
            contentView: contentView,
            position: .trailing
        )
        defer {
            NativeAccessoryContainerLayout.unregister(container: container)
        }

        NativeAccessoryContainerLayout.update(
            container: container,
            contentWidth: 44,
            position: .trailing
        )

        host.layoutIfNeeded()

        #expect(container.frame == CGRect(x: 56, y: 0, width: 44, height: 48))
    }

    @Test func sizingKeepsSystemFrameWidthForLaterGrowthAndCapsContentWidth() {
        guard #available(iOS 26.0, *) else {
            return
        }

        let host = AccessoryLayoutHostView(accessoryFrame: CGRect(x: 0, y: 0, width: 100, height: 48))
        let container = AccessoryContainerView(frame: host.accessoryFrame)
        let contentView = AccessoryContentView()
        host.bind(container)

        NativeAccessoryContainerLayout.register(
            container: container,
            contentView: contentView,
            position: .trailing
        )
        defer {
            NativeAccessoryContainerLayout.unregister(container: container)
        }

        NativeAccessoryContainerLayout.update(
            container: container,
            contentWidth: 44,
            position: .trailing
        )
        NativeAccessoryContainerLayout.update(
            container: container,
            contentWidth: 120,
            position: .trailing
        )

        host.layoutIfNeeded()

        #expect(container.frame == CGRect(x: 0, y: 0, width: 100, height: 48))
        #expect(NativeAccessoryContainerLayout.availableWidth(for: container) == 100)
        #expect(NativeAccessoryContainerLayout.availableHeight(for: container) == 48)
    }

    @Test func sizingAvailableHeightTracksSystemFrameChanges() {
        guard #available(iOS 26.0, *) else {
            return
        }

        let host = AccessoryLayoutHostView(accessoryFrame: CGRect(x: 0, y: 0, width: 100, height: 48))
        let container = AccessoryContainerView(frame: host.accessoryFrame)
        let contentView = AccessoryContentView()
        host.bind(container)

        NativeAccessoryContainerLayout.register(
            container: container,
            contentView: contentView,
            position: .trailing
        )
        defer {
            NativeAccessoryContainerLayout.unregister(container: container)
        }

        host.accessoryFrame.size.height = 32
        host.setNeedsLayout()
        host.layoutIfNeeded()
        #expect(NativeAccessoryContainerLayout.availableHeight(for: container) == 32)

        host.accessoryFrame.size.height = 64
        host.setNeedsLayout()
        host.layoutIfNeeded()
        #expect(NativeAccessoryContainerLayout.availableHeight(for: container) == 64)
    }

    @Test func sizingIgnoresInvalidContentWidth() {
        guard #available(iOS 26.0, *) else {
            return
        }

        let host = AccessoryLayoutHostView(accessoryFrame: CGRect(x: 0, y: 0, width: 100, height: 48))
        let container = AccessoryContainerView(frame: host.accessoryFrame)
        let contentView = AccessoryContentView()
        host.bind(container)

        NativeAccessoryContainerLayout.register(
            container: container,
            contentView: contentView,
            position: .trailing
        )
        defer {
            NativeAccessoryContainerLayout.unregister(container: container)
        }

        NativeAccessoryContainerLayout.update(
            container: container,
            contentWidth: .nan,
            position: .trailing
        )
        host.layoutIfNeeded()
        #expect(container.frame == CGRect(x: 0, y: 0, width: 100, height: 48))

        NativeAccessoryContainerLayout.update(
            container: container,
            contentWidth: -1,
            position: .trailing
        )
        host.layoutIfNeeded()
        #expect(container.frame == CGRect(x: 0, y: 0, width: 100, height: 48))
    }

    @Test func sizingUsesSystemFrameBeforeSuperviewWidth() {
        guard #available(iOS 26.0, *) else {
            return
        }

        let host = AccessoryLayoutHostView(accessoryFrame: CGRect(x: 50, y: 0, width: 100, height: 48))
        let container = AccessoryContainerView(frame: host.accessoryFrame)
        let contentView = AccessoryContentView()
        host.frame = CGRect(x: 0, y: 0, width: 300, height: 100)
        host.bind(container)

        NativeAccessoryContainerLayout.register(
            container: container,
            contentView: contentView,
            position: .trailing
        )
        defer {
            NativeAccessoryContainerLayout.unregister(container: container)
        }

        #expect(NativeAccessoryContainerLayout.availableWidth(for: container) == 100)
    }

    @Test func unregisteringSizingRestoresSystemFrame() {
        guard #available(iOS 26.0, *) else {
            return
        }

        let host = AccessoryLayoutHostView(accessoryFrame: CGRect(x: 0, y: 0, width: 100, height: 48))
        let container = AccessoryContainerView(frame: host.accessoryFrame)
        let contentView = AccessoryContentView()
        host.bind(container)

        NativeAccessoryContainerLayout.register(
            container: container,
            contentView: contentView,
            position: .trailing
        )
        NativeAccessoryContainerLayout.update(
            container: container,
            contentWidth: 44,
            position: .trailing
        )
        NativeAccessoryContainerLayout.unregister(container: container)
        host.layoutIfNeeded()

        #expect(container.frame == CGRect(x: 0, y: 0, width: 100, height: 48))
    }

    @Test func sizingSupportsLeadingCenterAndTrailingPositions() {
        guard #available(iOS 26.0, *) else {
            return
        }

        let host = AccessoryLayoutHostView(accessoryFrame: CGRect(x: 0, y: 0, width: 100, height: 48))
        let container = AccessoryContainerView(frame: host.accessoryFrame)
        let contentView = AccessoryContentView()
        host.bind(container)

        NativeAccessoryContainerLayout.register(
            container: container,
            contentView: contentView,
            position: .leading
        )
        defer {
            NativeAccessoryContainerLayout.unregister(container: container)
        }

        NativeAccessoryContainerLayout.update(
            container: container,
            contentWidth: 44,
            position: .leading
        )
        host.layoutIfNeeded()
        #expect(container.frame == CGRect(x: 0, y: 0, width: 44, height: 48))

        NativeAccessoryContainerLayout.update(
            container: container,
            contentWidth: 44,
            position: .center
        )
        host.layoutIfNeeded()
        #expect(container.frame == CGRect(x: 28, y: 0, width: 44, height: 48))

        NativeAccessoryContainerLayout.update(
            container: container,
            contentWidth: 44,
            position: .trailing
        )
        host.layoutIfNeeded()
        #expect(container.frame == CGRect(x: 56, y: 0, width: 44, height: 48))
    }

    @Test func sizingMirrorsLeadingAndTrailingInRightToLeftLayout() {
        guard #available(iOS 26.0, *) else {
            return
        }

        let host = AccessoryLayoutHostView(accessoryFrame: CGRect(x: 0, y: 0, width: 100, height: 48))
        let container = AccessoryContainerView(frame: host.accessoryFrame)
        let contentView = AccessoryContentView()
        host.semanticContentAttribute = .forceRightToLeft
        container.semanticContentAttribute = .forceRightToLeft
        host.bind(container)

        NativeAccessoryContainerLayout.register(
            container: container,
            contentView: contentView,
            position: .leading
        )
        defer {
            NativeAccessoryContainerLayout.unregister(container: container)
        }

        NativeAccessoryContainerLayout.update(
            container: container,
            contentWidth: 44,
            position: .leading
        )
        host.layoutIfNeeded()
        #expect(container.frame == CGRect(x: 56, y: 0, width: 44, height: 48))

        NativeAccessoryContainerLayout.update(
            container: container,
            contentWidth: 44,
            position: .trailing
        )
        host.layoutIfNeeded()
        #expect(container.frame == CGRect(x: 0, y: 0, width: 44, height: 48))
    }

    @Test func sizingCentersFrameUsingLayoutHostBounds() {
        guard #available(iOS 26.0, *) else {
            return
        }

        let host = AccessoryLayoutHostView(accessoryFrame: CGRect(x: 84, y: 0, width: 100, height: 48))
        let container = AccessoryContainerView(frame: host.accessoryFrame)
        let contentView = AccessoryContentView()
        host.frame = CGRect(x: 0, y: 0, width: 300, height: 100)
        host.bind(container)

        NativeAccessoryContainerLayout.register(
            container: container,
            contentView: contentView,
            position: .center
        )
        defer {
            NativeAccessoryContainerLayout.unregister(container: container)
        }

        NativeAccessoryContainerLayout.update(
            container: container,
            contentWidth: 44,
            position: .center
        )

        host.layoutIfNeeded()

        #expect(container.frame == CGRect(x: 128, y: 0, width: 44, height: 48))
    }

    @Test func unregisteredSizingKeepsDefaultFrameUpdates() {
        guard #available(iOS 26.0, *) else {
            return
        }

        let container = AccessoryContainerView(frame: CGRect(x: 0, y: 0, width: 100, height: 48))
        let contentView = UIView()

        NativeAccessoryContainerLayout.register(
            container: container,
            contentView: contentView,
            position: .trailing
        )
        NativeAccessoryContainerLayout.unregister(container: container)

        container.frame = CGRect(x: 10, y: 20, width: 200, height: 48)

        #expect(container.frame == CGRect(x: 10, y: 20, width: 200, height: 48))
    }
}

private final class NativeEnvironmentObservationCounter: @unchecked Sendable {
    var value = 0
}
