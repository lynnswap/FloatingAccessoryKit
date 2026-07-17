import UIKit
import UIKit.UIGestureRecognizerSubclass
@testable import FloatingAccessoryKit

@MainActor
func makeTestTabBarController(size: CGSize = CGSize(width: 390, height: 844)) -> UITabBarController {
    makeTestTabBarController(viewControllers: [UIViewController()], size: size)
}

@MainActor
func makeTestTabBarController(
    viewControllers: [UIViewController],
    size: CGSize = CGSize(width: 390, height: 844)
) -> UITabBarController {
    let tabBarController = UITabBarController()
    tabBarController.viewControllers = viewControllers
    tabBarController.loadViewIfNeeded()
    tabBarController.view.frame = CGRect(origin: .zero, size: size)
    tabBarController.view.setNeedsLayout()
    tabBarController.view.layoutIfNeeded()
    return tabBarController
}

@MainActor
func makeUITabTestTabBarController(size: CGSize = CGSize(width: 390, height: 844)) -> UITabBarController {
    let tabBarController = UITabBarController(
        tabs: [
            UITab(title: "Home", image: nil, identifier: "home") { _ in
                UIViewController()
            },
            UITab(title: "Settings", image: nil, identifier: "settings") { _ in
                UIViewController()
            }
        ]
    )
    tabBarController.loadViewIfNeeded()
    tabBarController.view.frame = CGRect(origin: .zero, size: size)
    tabBarController.view.setNeedsLayout()
    tabBarController.view.layoutIfNeeded()
    return tabBarController
}

@MainActor
func makeEmptyTestTabBarController(size: CGSize = CGSize(width: 390, height: 844)) -> UITabBarController {
    let tabBarController = UITabBarController()
    tabBarController.loadViewIfNeeded()
    tabBarController.view.frame = CGRect(origin: .zero, size: size)
    tabBarController.view.setNeedsLayout()
    tabBarController.view.layoutIfNeeded()
    return tabBarController
}

@discardableResult
@MainActor
func addTestTabBarButton(
    height: CGFloat,
    isHidden: Bool = false,
    alpha: CGFloat = 1,
    to tabBarController: UITabBarController
) -> UIView {
    guard let buttonClass = NSClassFromString(testTabBarButtonClassName()) as? UIView.Type else {
        fatalError("UITabBarButton class is unavailable")
    }

    let button = buttonClass.init(frame: CGRect(x: 0, y: 0, width: 80, height: height))
    button.isHidden = isHidden
    button.alpha = alpha
    tabBarController.tabBar.addSubview(button)
    return button
}

private func testTabBarButtonClassName() -> String {
    ["Button", "Bar", "Tab", "UI"].reversed().joined()
}

@MainActor
func constraintIDs(in views: [UIView]) -> Set<ObjectIdentifier> {
    Set(views.flatMap(\.constraints).map { ObjectIdentifier($0) })
}

@MainActor
func constraintsReferencing(_ item: AnyObject, in views: [UIView]) -> [NSLayoutConstraint] {
    views
        .flatMap(\.constraints)
        .filter { constraint in
            constraint.firstItem === item || constraint.secondItem === item
        }
}

@MainActor
func overlayHostViews(in tabBarController: UITabBarController) -> [UIView] {
    tabBarController.view.subviews.filter { view in
        view.subviews.contains { $0 is UIVisualEffectView }
    }
}

@MainActor
func revealHitAreaViews(in tabBarController: UITabBarController) -> [TabBarRevealHitAreaView] {
    tabBarController.view.subviews.compactMap { view in
        view as? TabBarRevealHitAreaView
    }
}

final class FixedSizeView: UIView {
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

final class IntrinsicOnlySizeView: UIView {
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
}

final class MutableSizeView: UIView {
    var size: CGSize {
        didSet {
            invalidateIntrinsicContentSize()
        }
    }

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

final class NoIntrinsicSizeView: UIView {
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        .zero
    }
}

final class LookalikeTabBarButton: UIControl {}

final class AccessoryContainerView: UIView {}

@available(iOS 26.0, *)
final class AccessoryContentView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)

        traitOverrides.tabAccessoryEnvironment = .regular
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class AccessoryLayoutHostView: UIView {
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

final class TestLongPressGestureRecognizer: UILongPressGestureRecognizer {
    func transition(to state: UIGestureRecognizer.State) {
        self.state = state
    }
}

@MainActor
final class AccessoryRendererHarness {
    private let renderer: any TabBarAccessoryRendering
    private(set) var state = TabBarAccessoryState()

    init(renderer: any TabBarAccessoryRendering) {
        self.renderer = renderer
    }

    var isHidden: Bool {
        state.isHidden
    }

    func setAccessoryView(
        _ view: UIView?,
        position: TabBarAccessoryController.Position,
        animated: Bool,
        in tabBarController: UITabBarController
    ) {
        let previousState = state
        state.contentView = view
        state.position = position
        _ = renderer.render(
            from: previousState,
            to: state,
            animated: animated,
            in: tabBarController
        )
    }

    func setHidden(
        _ hidden: Bool,
        animated: Bool,
        in tabBarController: UITabBarController
    ) {
        let previousState = state
        state.isHidden = hidden
        _ = renderer.render(
            from: previousState,
            to: state,
            animated: animated,
            in: tabBarController
        )
    }

    @discardableResult
    func update(
        in tabBarController: UITabBarController
    ) -> TabBarAccessoryRenderResult {
        renderer.update(state, in: tabBarController)
    }

    func tabBarVisibilityDidChange(
        hidden: Bool,
        animated: Bool,
        in tabBarController: UITabBarController
    ) {
        tabBarController.setTabBarHidden(hidden, animated: animated)
        _ = renderer.update(state, in: tabBarController)
    }
}

@MainActor
final class SpyAccessoryRenderer: TabBarAccessoryRendering {
    var contentSizeInvalidationHandler: (@MainActor (_ animated: Bool) -> Void)?

    private(set) var renderCallCount = 0
    private(set) var updateCallCount = 0
    private(set) var updateAnimationDurations: [TimeInterval] = []
    private(set) var lastState = TabBarAccessoryState()

    func render(
        from previousState: TabBarAccessoryState,
        to state: TabBarAccessoryState,
        animated: Bool,
        in tabBarController: UITabBarController
    ) -> TabBarAccessoryRenderResult {
        renderCallCount += 1
        lastState = state
        return .applied
    }

    func update(
        _ state: TabBarAccessoryState,
        in tabBarController: UITabBarController
    ) -> TabBarAccessoryRenderResult {
        updateCallCount += 1
        updateAnimationDurations.append(UIView.inheritedAnimationDuration)
        lastState = state
        return .applied
    }
}

@MainActor
final class ReentrantAccessoryRenderer: TabBarAccessoryRendering {
    var contentSizeInvalidationHandler: (@MainActor (_ animated: Bool) -> Void)?
    var nextRenderResult = TabBarAccessoryRenderResult.applied
    var onNextRender: (@MainActor () -> Void)?
    var onNextUpdate: (@MainActor () -> Void)?
    private(set) var renderedStates: [TabBarAccessoryState] = []
    private(set) var renderAnimations: [Bool] = []
    private(set) var updatedStates: [TabBarAccessoryState] = []
    private(set) var updateAnimationDurations: [TimeInterval] = []

    func render(
        from previousState: TabBarAccessoryState,
        to state: TabBarAccessoryState,
        animated: Bool,
        in tabBarController: UITabBarController
    ) -> TabBarAccessoryRenderResult {
        renderedStates.append(state)
        renderAnimations.append(animated)
        let onRender = onNextRender
        onNextRender = nil
        onRender?()
        let result = nextRenderResult
        nextRenderResult = .applied
        return result
    }

    func update(
        _ state: TabBarAccessoryState,
        in tabBarController: UITabBarController
    ) -> TabBarAccessoryRenderResult {
        updatedStates.append(state)
        updateAnimationDurations.append(UIView.inheritedAnimationDuration)
        let onUpdate = onNextUpdate
        onNextUpdate = nil
        onUpdate?()
        return .applied
    }
}
