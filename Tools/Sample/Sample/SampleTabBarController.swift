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

        tabBarMinimizeBehavior = .onScrollDown
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

    private func makePreviewTab(title: String, systemImageName: String) -> UIViewController {
        let viewController = UIHostingController(rootView: PreviewScrollView())
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

private struct PreviewScrollView: SwiftUI.View {
    var body: some SwiftUI.View {
        GeometryReader { geometry in
            let blockHeight = geometry.size.height * 0.6

            ScrollView {
                VStack(spacing: 0) {
                    Color.black
                        .frame(height: blockHeight)
                    Color(uiColor: UIColor.systemMint.withAlphaComponent(0.1))
                        .frame(height: blockHeight)
                    Color.black
                        .frame(height: blockHeight)
                }
                .frame(width: geometry.size.width)
            }
            .background(Color(uiColor: .systemBackground))
        }
    }
}

#if DEBUG
private struct SampleTabBarControllerPreview: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> SampleTabBarController {
        makeInteractivePreviewTabBarController()
    }

    func updateUIViewController(_ uiViewController: SampleTabBarController, context: Context) {
    }
}

private func makeInteractivePreviewTabBarController() -> SampleTabBarController {
    let accessoryView = PreviewAccessoryView()
    let tabBarController = SampleTabBarController(accessoryView: accessoryView)
    accessoryView.onContentSizeChange = { [weak tabBarController, weak accessoryView] in
        guard let tabBarController, let accessoryView else {
            return
        }

        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseInOut]) {
            tabBarController.setAccessory(
                accessoryView,
                animated: true
            )
            tabBarController.view.layoutIfNeeded()
        }
    }
    return tabBarController
}

private final class PreviewAccessoryView: UIStackView {
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
        makePreviewButton(
            systemImageName: "plus",
            accessibilityLabel: "Add"
        ) { [weak self] in
            self?.addRemoveButton()
        }
    }

    private func makeRemoveButton() -> UIButton {
        let button = makePreviewButton(
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

private func makePreviewButton(
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

#Preview("UIKit") {
    makeInteractivePreviewTabBarController()
}

#Preview("SwiftUI") {
    SampleTabBarControllerPreview()
        .ignoresSafeArea(.all, edges: .vertical)
}
#endif
