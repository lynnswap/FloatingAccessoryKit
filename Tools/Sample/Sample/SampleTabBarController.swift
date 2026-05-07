//
//  SampleTabBarController.swift
//  Sample
//
//  Created by Kazuki Nakashima on 2026/05/06.
//

import TabBarAccessoryKit
import SwiftUI
import UIKit

final class SampleTabBarController: UITabBarController {
    private var accessoryConfiguration: AccessoryConfiguration
    private var isAccessoryHidden = false
    private lazy var accessoryController = TabBarAccessoryController(tabBarController: self)

    private init(accessoryConfiguration: AccessoryConfiguration) {
        self.accessoryConfiguration = accessoryConfiguration

        super.init(nibName: nil, bundle: nil)
    }

    convenience init(
        accessoryView: UIView,
        accessoryPosition: TabBarAccessoryController.Position = .trailing
    ) {
        self.init(accessoryConfiguration: .uiView(accessoryView, position: accessoryPosition))
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
        viewControllers = [
            makePreviewTab(title: "Home", systemImageName: "house"),
            makePreviewTab(title: "Settings", systemImageName: "gearshape")
        ]

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

    private func makePreviewTab(title: String, systemImageName: String) -> UIViewController {
        let viewController = UIHostingController(rootView: SampleScrollView())
        viewController.view.backgroundColor = .systemBackground
        viewController.title = title
        viewController.tabBarItem = UITabBarItem(
            title: title,
            image: UIImage(systemName: systemImageName),
            selectedImage: nil
        )
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

private struct SampleScrollView: View {
    var body: some View {
        let blockHeight: CGFloat = 400

        ScrollView {
            VStack(spacing: 0) {
                Color.black
                    .frame(height: blockHeight)
                Color.mint.opacity(0.1)
                    .frame(height: blockHeight)
                Color.black
                    .frame(height: blockHeight)
            }
        }
    }
}

final class SampleTabBarAccessoryDemoNavigationController: UINavigationController {
    private enum Metrics {
        static let animationDuration: TimeInterval = 0.25
    }

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
        isAccessoryHidden: Bool = false
    ) {
        let accessoryView = SampleAccessoryView()
        self.accessoryPosition = accessoryPosition
        self.isTabBarHidden = isTabBarHidden
        self.isAccessoryHidden = isAccessoryHidden
        self.accessoryView = accessoryView
        self.sampleTabBarController = SampleTabBarController(
            accessoryView: accessoryView,
            accessoryPosition: accessoryPosition
        )

        super.init(rootViewController: sampleTabBarController)

        configureNavigationItem()
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

        sampleTabBarController.setTabBarHidden(isTabBarHidden, animated: false)
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
        setTabBarHiddenWithFade(isTabBarHidden, animated: true)
    }

    private func setTabBarHiddenWithFade(_ hidden: Bool, animated: Bool) {
        guard animated else {
            sampleTabBarController.setTabBarHidden(hidden, animated: false)
            sampleTabBarController.tabBar.alpha = 1
            return
        }

        sampleTabBarController.view.layoutIfNeeded()

        if hidden {
            let snapshot = sampleTabBarController.tabBar.snapshotView(afterScreenUpdates: false)
            snapshot?.frame = sampleTabBarController.tabBar.frame
            if let snapshot {
                sampleTabBarController.view.addSubview(snapshot)
            }
            sampleTabBarController.tabBar.alpha = 0

            UIView.animate(
                withDuration: Metrics.animationDuration,
                delay: 0,
                options: [.curveEaseInOut]
            ) {
                snapshot?.alpha = 0
                self.sampleTabBarController.setTabBarHidden(true, animated: false)
                self.sampleTabBarController.view.layoutIfNeeded()
            } completion: { _ in
                snapshot?.removeFromSuperview()
                self.sampleTabBarController.tabBar.alpha = 1
            }
        } else {
            sampleTabBarController.tabBar.alpha = 0

            UIView.animate(
                withDuration: Metrics.animationDuration,
                delay: 0,
                options: [.curveEaseInOut]
            ) {
                self.sampleTabBarController.setTabBarHidden(false, animated: false)
                self.sampleTabBarController.tabBar.alpha = 1
                self.sampleTabBarController.view.layoutIfNeeded()
            }
        }
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
    configuration.cornerStyle = .capsule
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
#Preview {
    SampleTabBarAccessoryDemoNavigationController()
}
#endif
