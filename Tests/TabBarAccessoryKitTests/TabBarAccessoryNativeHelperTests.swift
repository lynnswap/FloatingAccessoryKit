import Testing
import UIKit
@testable import TabBarAccessoryKit

@MainActor
@Suite(.serialized)
struct TabBarAccessoryNativeHelperTests {
    @Test func registeredContainerLimitsHitTestingToContent() {
        guard #available(iOS 26.0, *) else {
            return
        }

        let container = AccessoryContainerView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let button = UIButton(type: .system)
        button.frame = CGRect(x: 20, y: 20, width: 40, height: 40)
        container.addSubview(button)

        TabBarAccessoryHitTesting.register(container: container, contentView: button)
        defer {
            TabBarAccessoryHitTesting.unregister(container: container)
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

        TabBarAccessoryHitTesting.register(container: container, contentView: button)
        TabBarAccessoryHitTesting.unregister(container: container)

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

        TabBarAccessoryHitTesting.register(container: registeredContainer, contentView: registeredButton)
        defer {
            TabBarAccessoryHitTesting.unregister(container: registeredContainer)
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

        TabBarAccessoryHitTesting.register(container: container, contentView: button)
        defer {
            TabBarAccessoryHitTesting.unregister(container: container)
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

        TabBarAccessoryContainerSizing.register(
            container: container,
            contentView: contentView,
            position: .trailing
        )
        defer {
            TabBarAccessoryContainerSizing.unregister(container: container)
        }

        TabBarAccessoryContainerSizing.update(
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

        TabBarAccessoryContainerSizing.register(
            container: container,
            contentView: contentView,
            position: .trailing
        )
        defer {
            TabBarAccessoryContainerSizing.unregister(container: container)
        }

        TabBarAccessoryContainerSizing.update(
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

        TabBarAccessoryContainerSizing.register(
            container: container,
            contentView: contentView,
            position: .trailing
        )
        defer {
            TabBarAccessoryContainerSizing.unregister(container: container)
        }

        TabBarAccessoryContainerSizing.update(
            container: container,
            contentWidth: 44,
            position: .trailing
        )
        TabBarAccessoryContainerSizing.update(
            container: container,
            contentWidth: 120,
            position: .trailing
        )

        host.layoutIfNeeded()

        #expect(container.frame == CGRect(x: 0, y: 0, width: 100, height: 48))
        #expect(TabBarAccessoryContainerSizing.availableWidth(for: container) == 100)
    }

    @Test func sizingIgnoresInvalidContentWidth() {
        guard #available(iOS 26.0, *) else {
            return
        }

        let host = AccessoryLayoutHostView(accessoryFrame: CGRect(x: 0, y: 0, width: 100, height: 48))
        let container = AccessoryContainerView(frame: host.accessoryFrame)
        let contentView = AccessoryContentView()
        host.bind(container)

        TabBarAccessoryContainerSizing.register(
            container: container,
            contentView: contentView,
            position: .trailing
        )
        defer {
            TabBarAccessoryContainerSizing.unregister(container: container)
        }

        TabBarAccessoryContainerSizing.update(
            container: container,
            contentWidth: .nan,
            position: .trailing
        )
        host.layoutIfNeeded()
        #expect(container.frame == CGRect(x: 0, y: 0, width: 100, height: 48))

        TabBarAccessoryContainerSizing.update(
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

        TabBarAccessoryContainerSizing.register(
            container: container,
            contentView: contentView,
            position: .trailing
        )
        defer {
            TabBarAccessoryContainerSizing.unregister(container: container)
        }

        #expect(TabBarAccessoryContainerSizing.availableWidth(for: container) == 100)
    }

    @Test func unregisteringSizingRestoresSystemFrame() {
        guard #available(iOS 26.0, *) else {
            return
        }

        let host = AccessoryLayoutHostView(accessoryFrame: CGRect(x: 0, y: 0, width: 100, height: 48))
        let container = AccessoryContainerView(frame: host.accessoryFrame)
        let contentView = AccessoryContentView()
        host.bind(container)

        TabBarAccessoryContainerSizing.register(
            container: container,
            contentView: contentView,
            position: .trailing
        )
        TabBarAccessoryContainerSizing.update(
            container: container,
            contentWidth: 44,
            position: .trailing
        )
        TabBarAccessoryContainerSizing.unregister(container: container)
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

        TabBarAccessoryContainerSizing.register(
            container: container,
            contentView: contentView,
            position: .leading
        )
        defer {
            TabBarAccessoryContainerSizing.unregister(container: container)
        }

        TabBarAccessoryContainerSizing.update(
            container: container,
            contentWidth: 44,
            position: .leading
        )
        host.layoutIfNeeded()
        #expect(container.frame == CGRect(x: 0, y: 0, width: 44, height: 48))

        TabBarAccessoryContainerSizing.update(
            container: container,
            contentWidth: 44,
            position: .center
        )
        host.layoutIfNeeded()
        #expect(container.frame == CGRect(x: 28, y: 0, width: 44, height: 48))

        TabBarAccessoryContainerSizing.update(
            container: container,
            contentWidth: 44,
            position: .trailing
        )
        host.layoutIfNeeded()
        #expect(container.frame == CGRect(x: 56, y: 0, width: 44, height: 48))
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

        TabBarAccessoryContainerSizing.register(
            container: container,
            contentView: contentView,
            position: .center
        )
        defer {
            TabBarAccessoryContainerSizing.unregister(container: container)
        }

        TabBarAccessoryContainerSizing.update(
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

        TabBarAccessoryContainerSizing.register(
            container: container,
            contentView: contentView,
            position: .trailing
        )
        TabBarAccessoryContainerSizing.unregister(container: container)

        container.frame = CGRect(x: 10, y: 20, width: 200, height: 48)

        #expect(container.frame == CGRect(x: 10, y: 20, width: 200, height: 48))
    }
}
