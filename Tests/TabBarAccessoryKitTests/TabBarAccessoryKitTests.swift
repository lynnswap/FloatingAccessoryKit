import Testing
import UIKit
@testable import TabBarAccessoryKit

@MainActor
@Test func registeredAccessoryContainerPassesThroughOutsideContent() {
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

@MainActor
@Test func unregisteredAccessoryContainerKeepsDefaultHitTesting() {
    let container = AccessoryContainerView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    let button = UIButton(type: .system)
    button.frame = CGRect(x: 20, y: 20, width: 40, height: 40)
    container.addSubview(button)

    TabBarAccessoryHitTesting.register(container: container, contentView: button)
    TabBarAccessoryHitTesting.unregister(container: container)

    #expect(container.hitTest(CGPoint(x: 10, y: 10), with: nil) === container)
    #expect(container.hitTest(CGPoint(x: 30, y: 30), with: nil) === button)
}

@MainActor
@Test func registeringOneContainerDoesNotAffectUnregisteredContainersOfSameClass() {
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

@MainActor
@Test func registeringPlainUIViewDoesNotChangeDefaultUIViewHitTesting() {
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

@MainActor
@Test func accessoryContainerSizingShrinksTrailingFrameToContentWidth() {
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

@MainActor
@Test func accessoryContainerSizingKeepsSystemFrameForLaterGrowth() {
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
        contentWidth: 88,
        position: .trailing
    )

    host.layoutIfNeeded()

    #expect(container.frame == CGRect(x: 12, y: 0, width: 88, height: 48))
    #expect(TabBarAccessoryContainerSizing.availableWidth(for: container) == 100)
}

@MainActor
@Test func accessoryContainerSizingUsesSystemFrameBeforeSuperviewWidth() {
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

@MainActor
@Test func unregisteringAccessoryContainerSizingRestoresSystemFrame() {
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

@MainActor
@Test func accessoryContainerSizingRecentersFrame() {
    let host = AccessoryLayoutHostView(accessoryFrame: CGRect(x: 0, y: 0, width: 100, height: 48))
    let container = AccessoryContainerView(frame: host.accessoryFrame)
    let contentView = AccessoryContentView()
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

    #expect(container.frame == CGRect(x: 28, y: 0, width: 44, height: 48))
}

@MainActor
@Test func unregisteredAccessoryContainerSizingKeepsDefaultFrameUpdates() {
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

private final class AccessoryContainerView: UIView {}

private final class AccessoryContentView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)

        traitOverrides.tabAccessoryEnvironment = .regular
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class AccessoryLayoutHostView: UIView {
    var accessoryFrame: CGRect
    private weak var accessoryContainer: UIView?

    init(accessoryFrame: CGRect) {
        self.accessoryFrame = accessoryFrame

        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(_ container: UIView) {
        accessoryContainer = container
        addSubview(container)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        accessoryContainer?.frame = frameForHostedElement(2, options: 0)
    }

    @objc(frameForHostedElement:options:)
    dynamic func frameForHostedElement(_ element: Int, options: Int) -> CGRect {
        element == 2 ? accessoryFrame : .zero
    }
}
