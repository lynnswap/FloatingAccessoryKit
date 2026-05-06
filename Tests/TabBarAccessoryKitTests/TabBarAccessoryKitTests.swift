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

private final class AccessoryContainerView: UIView {}
