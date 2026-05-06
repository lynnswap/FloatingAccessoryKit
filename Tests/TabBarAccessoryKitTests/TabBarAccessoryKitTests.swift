import Testing
import UIKit
@testable import TabBarAccessoryKit

@MainActor
@Test func registeredAccessoryContainerPassesThroughOutsideContent() {
    let container = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
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
    let container = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    let button = UIButton(type: .system)
    button.frame = CGRect(x: 20, y: 20, width: 40, height: 40)
    container.addSubview(button)

    TabBarAccessoryHitTesting.register(container: container, contentView: button)
    TabBarAccessoryHitTesting.unregister(container: container)

    #expect(container.hitTest(CGPoint(x: 10, y: 10), with: nil) === container)
    #expect(container.hitTest(CGPoint(x: 30, y: 30), with: nil) === button)
}
