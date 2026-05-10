//
//  SampleTabBarController.swift
//  Sample
//
//  Created by Kazuki Nakashima on 2026/05/06.
//

import TabBarAccessoryKit
import UIKit

final class SampleTabBarController: UITabBarController {
    private enum Metrics {
        static let animationDuration: TimeInterval = 0.25
    }

    private var accessoryConfiguration: AccessoryConfiguration
    private let usesUITabs: Bool
    private var isAccessoryHidden = false
    private var requestedTabBarHidden = false
    private lazy var accessoryController = TabBarAccessoryController(tabBarController: self)

    var onTabBarVisibilityChange: (@MainActor (Bool) -> Void)?

    private init(accessoryConfiguration: AccessoryConfiguration, usesUITabs: Bool) {
        self.accessoryConfiguration = accessoryConfiguration
        self.usesUITabs = usesUITabs

        super.init(nibName: nil, bundle: nil)
    }

    convenience init(
        accessoryView: UIView,
        accessoryPosition: TabBarAccessoryController.Position = .trailing,
        usesUITabs: Bool = false
    ) {
        self.init(
            accessoryConfiguration: .uiView(accessoryView, position: accessoryPosition),
            usesUITabs: usesUITabs
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if #available(iOS 26.0, *) {
            tabBarMinimizeBehavior = .onScrollDown
        }
        configureTabs()

        applyAccessoryConfigurationIfNeeded()
    }

    func setAccessory(
        _ accessoryView: UIView,
        position: TabBarAccessoryController.Position = .trailing,
        animated: Bool = false
    ) {
        accessoryConfiguration = .uiView(
            accessoryView,
            position: position,
            animated: animated
        )
        applyAccessoryConfigurationIfNeeded()
    }

    func setAccessoryHidden(_ hidden: Bool, animated: Bool = false) {
        isAccessoryHidden = hidden
        guard isViewLoaded else {
            return
        }

        accessoryController.setHidden(hidden, animated: animated)
    }

    func setTabBarHiddenWithFade(_ hidden: Bool, animated: Bool) {
        guard hidden != requestedTabBarHidden else {
            return
        }

        requestedTabBarHidden = hidden
        onTabBarVisibilityChange?(hidden)

        guard animated else {
            setTabBarHidden(hidden, animated: false)
            tabBar.alpha = 1
            return
        }

        view.layoutIfNeeded()

        if hidden {
            let snapshot = tabBar.snapshotView(afterScreenUpdates: false)
            snapshot?.frame = tabBar.frame
            if let snapshot {
                view.addSubview(snapshot)
            }
            tabBar.alpha = 0

            UIView.animate(
                withDuration: Metrics.animationDuration,
                delay: 0,
                options: [.curveEaseInOut]
            ) {
                snapshot?.alpha = 0
                self.setTabBarHidden(true, animated: false)
                self.view.layoutIfNeeded()
            } completion: { _ in
                snapshot?.removeFromSuperview()
                self.tabBar.alpha = 1
            }
        } else {
            tabBar.alpha = 0

            UIView.animate(
                withDuration: Metrics.animationDuration,
                delay: 0,
                options: [.curveEaseInOut]
            ) {
                self.setTabBarHidden(false, animated: false)
                self.tabBar.alpha = 1
                self.view.layoutIfNeeded()
            }
        }
    }

    private func configureTabs() {
        if usesUITabs {
            tabs = [
                Self.makePreviewUITab(
                    title: "Home",
                    systemImageName: "house",
                    identifier: "home"
                ),
                Self.makePreviewUITab(
                    title: "Settings",
                    systemImageName: "gearshape",
                    identifier: "settings"
                )
            ]
        } else {
            viewControllers = [
                Self.makePreviewViewControllerTab(title: "Home", systemImageName: "house"),
                Self.makePreviewViewControllerTab(title: "Settings", systemImageName: "gearshape")
            ]
        }
    }

    private static func makePreviewViewControllerTab(title: String, systemImageName: String) -> UIViewController {
        let viewController = makePreviewContentViewController(title: title)
        viewController.tabBarItem = UITabBarItem(
            title: title,
            image: UIImage(systemName: systemImageName),
            selectedImage: nil
        )
        return viewController
    }

    private static func makePreviewUITab(title: String, systemImageName: String, identifier: String) -> UITab {
        UITab(
            title: title,
            image: UIImage(systemName: systemImageName),
            identifier: identifier
        ) { _ in
            makePreviewContentViewController(title: title)
        }
    }

    private static func makePreviewContentViewController(title: String) -> UIViewController {
        let viewController = SampleScrollViewController()
        viewController.view.backgroundColor = .systemBackground
        viewController.title = title
        return viewController
    }

    private func applyAccessoryConfigurationIfNeeded() {
        guard isViewLoaded else {
            return
        }

        accessoryConfiguration.configure(accessoryController)
        accessoryController.setHidden(isAccessoryHidden)
    }
}

private struct AccessoryConfiguration {
    let configure: @MainActor (TabBarAccessoryController) -> Void

    static func uiView(
        _ view: UIView,
        position: TabBarAccessoryController.Position,
        animated: Bool = false
    ) -> Self {
        AccessoryConfiguration { accessoryController in
            accessoryController.setContent(
                view,
                position: position,
                animated: animated
            )
        }
    }
}

private final class SampleScrollViewController: UIViewController, UIScrollViewDelegate {
    private enum Metrics {
        static let blockHeight: CGFloat = 400
        static let tabBarToggleThreshold: CGFloat = 60
    }

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let contentInsetOverlayView = SampleContentInsetOverlayView()
    private var lastContentOffsetY: CGFloat = 0
    private var accumulatedScrollDelta: CGFloat = 0

    override func loadView() {
        view = UIView()
        view.backgroundColor = .systemBackground

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentInsetOverlayView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentInsetOverlayView)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 0
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentInsetOverlayView.topAnchor.constraint(equalTo: view.topAnchor),
            contentInsetOverlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentInsetOverlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentInsetOverlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        [
            UIColor.black,
            UIColor.systemMint.withAlphaComponent(0.1),
            UIColor.black
        ].forEach(addBlockView(color:))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if #unavailable(iOS 26.0) {
            scrollView.delegate = self
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        updateContentInsetOverlay()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()

        updateContentInsetOverlay()
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        lastContentOffsetY = scrollView.contentOffset.y
        accumulatedScrollDelta = 0
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if #available(iOS 26.0, *) {
            return
        }

        let offsetY = scrollView.contentOffset.y
        let topOffsetY = -scrollView.adjustedContentInset.top
        let bottomOffsetY = max(
            topOffsetY,
            scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom
        )

        guard offsetY > topOffsetY else {
            setTabBarHiddenFromScroll(false)
            resetScrollTracking(offsetY)
            return
        }

        guard offsetY < bottomOffsetY else {
            resetScrollTracking(offsetY)
            return
        }

        let delta = offsetY - lastContentOffsetY
        lastContentOffsetY = offsetY

        guard delta != 0 else {
            return
        }

        if delta > 0 {
            accumulatedScrollDelta = max(0, accumulatedScrollDelta) + delta
        } else {
            accumulatedScrollDelta = min(0, accumulatedScrollDelta) + delta
        }

        if accumulatedScrollDelta >= Metrics.tabBarToggleThreshold {
            setTabBarHiddenFromScroll(true)
            accumulatedScrollDelta = 0
        } else if accumulatedScrollDelta <= -Metrics.tabBarToggleThreshold {
            setTabBarHiddenFromScroll(false)
            accumulatedScrollDelta = 0
        }
    }

    private func addBlockView(color: UIColor) {
        let blockView = UIView()
        blockView.backgroundColor = color
        stackView.addArrangedSubview(blockView)
        blockView.heightAnchor.constraint(equalToConstant: Metrics.blockHeight).isActive = true
    }

    private func resetScrollTracking(_ offsetY: CGFloat) {
        lastContentOffsetY = offsetY
        accumulatedScrollDelta = 0
    }

    private func setTabBarHiddenFromScroll(_ hidden: Bool) {
        (tabBarController as? SampleTabBarController)?.setTabBarHiddenWithFade(
            hidden,
            animated: true
        )
    }

    private func updateContentInsetOverlay() {
        contentInsetOverlayView.update(
            safeAreaInsets: view.safeAreaInsets,
            adjustedContentInset: scrollView.adjustedContentInset
        )
    }
}

private final class SampleContentInsetOverlayView: UIView {
    private let safeAreaFrameView = UIView()
    private let adjustedContentFrameView = UIView()
    private let topAdjustedInsetView = UIView()
    private let bottomAdjustedInsetView = UIView()
    private let leftAdjustedInsetView = UIView()
    private let rightAdjustedInsetView = UIView()
    private var representedSafeAreaInsets = UIEdgeInsets.zero
    private var representedAdjustedContentInset = UIEdgeInsets.zero

    override init(frame: CGRect) {
        super.init(frame: frame)

        isUserInteractionEnabled = false
        backgroundColor = .clear

        [topAdjustedInsetView, bottomAdjustedInsetView, leftAdjustedInsetView, rightAdjustedInsetView].forEach {
            $0.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.14)
            addSubview($0)
        }

        adjustedContentFrameView.backgroundColor = .clear
        adjustedContentFrameView.layer.borderColor = UIColor.systemBlue.cgColor
        adjustedContentFrameView.layer.borderWidth = 2
        addSubview(adjustedContentFrameView)

        safeAreaFrameView.backgroundColor = .clear
        safeAreaFrameView.layer.borderColor = UIColor.systemGreen.cgColor
        safeAreaFrameView.layer.borderWidth = 2
        addSubview(safeAreaFrameView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(
        safeAreaInsets: UIEdgeInsets,
        adjustedContentInset: UIEdgeInsets
    ) {
        representedSafeAreaInsets = sanitized(safeAreaInsets)
        representedAdjustedContentInset = sanitized(adjustedContentInset)
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let safeFrame = bounds.inset(by: representedSafeAreaInsets)
        let adjustedFrame = bounds.inset(by: representedAdjustedContentInset)

        safeAreaFrameView.frame = safeFrame
        adjustedContentFrameView.frame = adjustedFrame

        topAdjustedInsetView.frame = CGRect(
            x: bounds.minX,
            y: bounds.minY,
            width: bounds.width,
            height: representedAdjustedContentInset.top
        )
        bottomAdjustedInsetView.frame = CGRect(
            x: bounds.minX,
            y: bounds.maxY - representedAdjustedContentInset.bottom,
            width: bounds.width,
            height: representedAdjustedContentInset.bottom
        )
        leftAdjustedInsetView.frame = CGRect(
            x: bounds.minX,
            y: adjustedFrame.minY,
            width: representedAdjustedContentInset.left,
            height: adjustedFrame.height
        )
        rightAdjustedInsetView.frame = CGRect(
            x: bounds.maxX - representedAdjustedContentInset.right,
            y: adjustedFrame.minY,
            width: representedAdjustedContentInset.right,
            height: adjustedFrame.height
        )
    }

    private func sanitized(_ insets: UIEdgeInsets) -> UIEdgeInsets {
        UIEdgeInsets(
            top: sanitized(insets.top),
            left: sanitized(insets.left),
            bottom: sanitized(insets.bottom),
            right: sanitized(insets.right)
        )
    }

    private func sanitized(_ value: CGFloat) -> CGFloat {
        guard value.isFinite,
              value > 0 else {
            return 0
        }

        return value
    }
}

final class SampleTabBarAccessoryDemoNavigationController: UINavigationController {
    private let positionControl = UISegmentedControl(
        items: ["leading", "center", "trailing"]
    )
    private let tabBarVisibilitySwitch = UISwitch()
    private let accessoryVisibilitySwitch = UISwitch()
    private let accessoryView: SampleAccessoryView
    private let sampleTabBarController: SampleTabBarController

    private var accessoryPosition: TabBarAccessoryController.Position
    private var isTabBarHidden: Bool
    private var isAccessoryHidden: Bool

    init(
        accessoryPosition: TabBarAccessoryController.Position = .trailing,
        isTabBarHidden: Bool = false,
        isAccessoryHidden: Bool = false,
        usesUITabs: Bool = false
    ) {
        let accessoryView = SampleAccessoryView()
        self.accessoryPosition = accessoryPosition
        self.isTabBarHidden = isTabBarHidden
        self.isAccessoryHidden = isAccessoryHidden
        self.accessoryView = accessoryView
        self.sampleTabBarController = SampleTabBarController(
            accessoryView: accessoryView,
            accessoryPosition: accessoryPosition,
            usesUITabs: usesUITabs
        )

        super.init(rootViewController: sampleTabBarController)

        configureNavigationItem()
        sampleTabBarController.onTabBarVisibilityChange = { [weak self] hidden in
            self?.syncTabBarVisibility(hidden)
        }
        accessoryView.onContentSizeChange = { [weak self] in
            self?.updateAccessorySize()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        sampleTabBarController.setTabBarHiddenWithFade(isTabBarHidden, animated: false)
        sampleTabBarController.setAccessoryHidden(isAccessoryHidden)
    }

    private func configureNavigationItem() {
        positionControl.selectedSegmentIndex = segmentIndex(for: accessoryPosition)
        positionControl.addAction(
            UIAction { [weak self] _ in
                self?.accessoryPositionDidChange()
            },
            for: .valueChanged
        )

        tabBarVisibilitySwitch.isOn = !isTabBarHidden
        tabBarVisibilitySwitch.accessibilityLabel = "Tab Bar"
        tabBarVisibilitySwitch.addAction(
            UIAction { [weak self] _ in
                self?.tabBarVisibilityDidChange()
            },
            for: .valueChanged
        )

        accessoryVisibilitySwitch.isOn = !isAccessoryHidden
        accessoryVisibilitySwitch.accessibilityLabel = "Accessory"
        accessoryVisibilitySwitch.addAction(
            UIAction { [weak self] _ in
                self?.accessoryVisibilityDidChange()
            },
            for: .valueChanged
        )

        sampleTabBarController.navigationItem.leftBarButtonItem = UIBarButtonItem(
            customView: makeTabBarVisibilityControl(tabBarVisibilitySwitch)
        )
        sampleTabBarController.navigationItem.titleView = positionControl
        sampleTabBarController.navigationItem.rightBarButtonItem = UIBarButtonItem(
            customView: accessoryVisibilitySwitch
        )
    }

    private func accessoryPositionDidChange() {
        accessoryPosition = selectedAccessoryPosition()
        updateAccessory(animated: true)
    }

    private func accessoryVisibilityDidChange() {
        isAccessoryHidden = !accessoryVisibilitySwitch.isOn
        sampleTabBarController.setAccessoryHidden(isAccessoryHidden, animated: true)
    }

    private func tabBarVisibilityDidChange() {
        isTabBarHidden = !tabBarVisibilitySwitch.isOn
        sampleTabBarController.setTabBarHiddenWithFade(isTabBarHidden, animated: true)
    }

    private func updateAccessorySize() {
        updateAccessory(animated: true)
    }

    private func updateAccessory(animated: Bool) {
        let animations = {
            self.sampleTabBarController.setAccessory(
                self.accessoryView,
                position: self.accessoryPosition,
                animated: animated
            )
            self.sampleTabBarController.setAccessoryHidden(
                self.isAccessoryHidden,
                animated: animated
            )
            self.sampleTabBarController.view.layoutIfNeeded()
        }

        guard animated else {
            animations()
            return
        }

        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseInOut]) {
            animations()
        }
    }

    private func selectedAccessoryPosition() -> TabBarAccessoryController.Position {
        switch positionControl.selectedSegmentIndex {
        case 0:
            .leading
        case 1:
            .center
        case 2:
            .trailing
        default:
            accessoryPosition
        }
    }

    private func segmentIndex(for position: TabBarAccessoryController.Position) -> Int {
        switch position {
        case .leading:
            0
        case .center:
            1
        case .trailing:
            2
        }
    }

    private func syncTabBarVisibility(_ hidden: Bool) {
        isTabBarHidden = hidden
        let isOn = !hidden
        guard tabBarVisibilitySwitch.isOn != isOn else {
            return
        }

        tabBarVisibilitySwitch.setOn(isOn, animated: true)
    }
}

private func makeTabBarVisibilityControl(_ visibilitySwitch: UISwitch) -> UIView {
    let label = UILabel()
    label.text = "Tab Bar"
    label.font = .preferredFont(forTextStyle: .caption1)
    label.adjustsFontForContentSizeCategory = true

    let stackView = UIStackView(arrangedSubviews: [label, visibilitySwitch])
    stackView.axis = .horizontal
    stackView.alignment = .center
    stackView.spacing = 6
    return stackView
}

private final class SampleAccessoryView: UIStackView {
    private static let minimumButtonLength: CGFloat = 44

    private let minusButtonStack = UIStackView()

    var onContentSizeChange: (@MainActor () -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)

        axis = .horizontal
        spacing = 0
        distribution = .fill

        minusButtonStack.axis = .horizontal
        minusButtonStack.spacing = 0
        minusButtonStack.distribution = .fill
        addArrangedSubview(minusButtonStack)
        addArrangedSubview(makeAddButton())
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        let visibleButtonCount = minusButtonStack.arrangedSubviews.filter { !$0.isHidden }.count + 1
        guard visibleButtonCount > 0 else {
            return .zero
        }

        let side = max(bounds.height, Self.minimumButtonLength)
        let width = CGFloat(visibleButtonCount) * side + CGFloat(visibleButtonCount - 1) * spacing

        return CGSize(width: width, height: side)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        intrinsicContentSize
    }

    private func makeAddButton() -> UIButton {
        makeAccessoryButton(
            systemImageName: "plus",
            accessibilityLabel: "Add"
        ) { [weak self] in
            self?.addRemoveButton()
        }
    }

    private func makeRemoveButton() -> UIButton {
        let button = makeAccessoryButton(
            systemImageName: "minus",
            accessibilityLabel: "Remove"
        )
        button.addAction(
            UIAction { [weak self, weak button] _ in
                guard let button else {
                    return
                }

                self?.removeRemoveButton(button)
            },
            for: .touchUpInside
        )
        return button
    }

    private func addRemoveButton() {
        let button = makeRemoveButton()
        button.alpha = 0
        minusButtonStack.insertArrangedSubview(button, at: 0)
        notifyContentSizeDidChange()

        UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseInOut]) {
            button.alpha = 1
            self.layoutIfNeeded()
        }
    }

    private func removeRemoveButton(_ button: UIButton) {
        minusButtonStack.removeArrangedSubview(button)
        notifyContentSizeDidChange()

        UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseInOut]) {
            button.alpha = 0
            self.layoutIfNeeded()
        } completion: { _ in
            button.removeFromSuperview()
        }
    }

    private func notifyContentSizeDidChange() {
        minusButtonStack.invalidateIntrinsicContentSize()
        invalidateIntrinsicContentSize()
        onContentSizeChange?()
    }
}

private func makeAccessoryButton(
    systemImageName: String,
    accessibilityLabel: String,
    action: (@MainActor () -> Void)? = nil
) -> UIButton {
    let button = UIButton(type: .system)
    var configuration = UIButton.Configuration.plain()
    configuration.image = UIImage(systemName: systemImageName)
    configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(scale: .medium)
    button.configuration = configuration
    button.accessibilityLabel = accessibilityLabel
    button.contentHorizontalAlignment = .center
    button.contentVerticalAlignment = .center
    button.setContentHuggingPriority(.required, for: .horizontal)
    button.setContentCompressionResistancePriority(.required, for: .horizontal)
    button.widthAnchor.constraint(equalTo: button.heightAnchor).isActive = true
    if let action {
        button.addAction(
            UIAction { _ in
                action()
            },
            for: .touchUpInside
        )
    }
    return button
}

#if DEBUG
#Preview("View Controller Tabs") {
    SampleTabBarAccessoryDemoNavigationController()
}

#Preview("UITab Tabs") {
    SampleTabBarAccessoryDemoNavigationController(usesUITabs: true)
}
#endif
