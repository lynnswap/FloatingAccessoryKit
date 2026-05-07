import Testing
import UIKit
@testable import TabBarAccessoryKit

@MainActor
@Test func overlayAccessoryPositionsAboveVisibleTabBar() {
    let tabBarController = makeOverlayTabBarController()
    let coordinator = OverlayTabBarAccessoryCoordinator()
    let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

    coordinator.setAccessoryView(
        contentView,
        position: .trailing,
        animated: false,
        in: tabBarController
    )
    tabBarController.view.layoutIfNeeded()

    let hostView = contentView.superview
    let tabBarFrame = tabBarController.tabBar.convert(
        tabBarController.tabBar.bounds,
        to: tabBarController.view
    )
    let safeAreaFrame = tabBarController.view.safeAreaLayoutGuide.layoutFrame

    #expect(hostView != nil)
    #expect(abs((hostView?.frame.maxY ?? 0) - (tabBarFrame.minY - 8)) <= 0.5)
    #expect(abs((hostView?.frame.maxX ?? 0) - (safeAreaFrame.maxX - 8)) <= 0.5)
}

@MainActor
@Test func overlayAccessoryUsesBarMaterialBackground() {
    let tabBarController = makeOverlayTabBarController()
    let coordinator = OverlayTabBarAccessoryCoordinator()
    let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

    coordinator.setAccessoryView(
        contentView,
        position: .trailing,
        animated: false,
        in: tabBarController
    )
    tabBarController.view.layoutIfNeeded()

    let hostView = contentView.superview
    let effectView = hostView?.subviews.compactMap { $0 as? UIVisualEffectView }.first

    #expect(effectView != nil)
    #expect(hostView?.clipsToBounds == true)
    #expect(abs((hostView?.layer.cornerRadius ?? 0) - 24) <= 0.5)
}

@MainActor
@Test func overlayAccessoryFollowsTabBarWhenHidden() {
    let tabBarController = makeOverlayTabBarController()
    let coordinator = OverlayTabBarAccessoryCoordinator()
    let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

    coordinator.setAccessoryView(
        contentView,
        position: .trailing,
        animated: false,
        in: tabBarController
    )
    tabBarController.view.layoutIfNeeded()
    let visibleBottomY = contentView.superview?.frame.maxY ?? 0

    coordinator.tabBarVisibilityDidChange(
        hidden: true,
        animated: false,
        in: tabBarController
    )
    tabBarController.view.layoutIfNeeded()

    let hostView = contentView.superview
    let expectedBottomY = tabBarController.view.safeAreaLayoutGuide.layoutFrame.maxY - 8

    #expect(hostView != nil)
    #expect(abs((hostView?.frame.maxY ?? 0) - expectedBottomY) <= 0.5)
    #expect((hostView?.frame.maxY ?? 0) > visibleBottomY)
}

@MainActor
@Test func overlayAccessoryRespectsSafeAreaWhenTabBarIsHidden() {
    let tabBarController = makeOverlayTabBarController()
    tabBarController.additionalSafeAreaInsets.bottom = 34
    tabBarController.view.layoutIfNeeded()

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
    tabBarController.view.layoutIfNeeded()

    let hostView = contentView.superview
    let expectedBottomY = tabBarController.view.safeAreaLayoutGuide.layoutFrame.maxY - 8

    #expect(hostView != nil)
    #expect(abs((hostView?.frame.maxY ?? 0) - expectedBottomY) <= 0.5)
}

@MainActor
@Test func overlayAccessoryUpdatesHorizontalPositionWithoutReplacingContent() {
    let tabBarController = makeOverlayTabBarController()
    let coordinator = OverlayTabBarAccessoryCoordinator()
    let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

    coordinator.setAccessoryView(
        contentView,
        position: .center,
        animated: false,
        in: tabBarController
    )
    tabBarController.view.layoutIfNeeded()

    let hostView = contentView.superview
    let safeAreaFrame = tabBarController.view.safeAreaLayoutGuide.layoutFrame
    #expect(abs((hostView?.frame.midX ?? 0) - safeAreaFrame.midX) <= 0.5)

    coordinator.setAccessoryView(
        contentView,
        position: .leading,
        animated: false,
        in: tabBarController
    )
    tabBarController.view.layoutIfNeeded()

    #expect(contentView.superview === hostView)
    #expect(abs((hostView?.frame.minX ?? 0) - (safeAreaFrame.minX + 8)) <= 0.5)
}

@MainActor
@Test func overlayAccessoryRepeatedUpdatesReuseInstalledConstraints() {
    let tabBarController = makeOverlayTabBarController()
    let coordinator = OverlayTabBarAccessoryCoordinator()
    let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

    coordinator.setAccessoryView(
        contentView,
        position: .trailing,
        animated: false,
        in: tabBarController
    )
    tabBarController.view.layoutIfNeeded()

    let hostView = contentView.superview!
    let initialConstraintIDs = constraintIDs(in: [tabBarController.view, hostView])

    for _ in 0..<10 {
        coordinator.update(in: tabBarController)
        tabBarController.view.layoutIfNeeded()
    }

    #expect(constraintIDs(in: [tabBarController.view, hostView]) == initialConstraintIDs)
}

@MainActor
@Test func overlayAccessoryReplacesContentViewWithoutLeavingOldSuperview() {
    let tabBarController = makeOverlayTabBarController()
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
    #expect(secondView.superview != nil)
    #expect(secondView.superview?.bounds.size == CGSize(width: 96, height: 48))
}

@available(iOS 26.0, *)
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

@available(iOS 26.0, *)
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

@available(iOS 26.0, *)
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

@available(iOS 26.0, *)
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

@available(iOS 26.0, *)
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

@available(iOS 26.0, *)
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

@available(iOS 26.0, *)
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

@available(iOS 26.0, *)
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

@available(iOS 26.0, *)
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

@available(iOS 26.0, *)
@MainActor
@Test func accessoryContainerSizingCentersFrameUsingLayoutHostBounds() {
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

@available(iOS 26.0, *)
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

private final class FixedSizeView: UIView {
    let size: CGSize

    init(size: CGSize) {
        self.size = size

        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        size
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        self.size
    }
}

@MainActor
private func makeOverlayTabBarController() -> UITabBarController {
    let tabBarController = UITabBarController()
    tabBarController.viewControllers = [UIViewController()]
    tabBarController.loadViewIfNeeded()
    tabBarController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
    tabBarController.view.setNeedsLayout()
    tabBarController.view.layoutIfNeeded()
    return tabBarController
}

@MainActor
private func constraintIDs(in views: [UIView]) -> Set<ObjectIdentifier> {
    Set(views.flatMap { $0.constraints }.map { ObjectIdentifier($0) })
}

@available(iOS 26.0, *)
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
