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
        position: TabBarAccessoryController.Position = .trailing
    ) {
        accessoryConfiguration = .uiView(accessoryView, position: position)
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
        position: TabBarAccessoryController.Position
    ) -> Self {
        AccessoryConfiguration { accessoryController in
            accessoryController.setContent(
                view,
                position: position
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
    private let accessoryPosition: TabBarAccessoryController.Position
    private let accessoryView: @MainActor () -> UIView

    init(
        accessoryPosition: TabBarAccessoryController.Position = .trailing,
        accessoryView: @escaping @MainActor () -> UIView
    ) {
        self.accessoryPosition = accessoryPosition
        self.accessoryView = accessoryView
    }

    func makeUIViewController(context: Context) -> SampleTabBarController {
        SampleTabBarController(
            accessoryView: accessoryView(),
            accessoryPosition: accessoryPosition
        )
    }

    func updateUIViewController(_ uiViewController: SampleTabBarController, context: Context) {
        uiViewController.setAccessory(
            accessoryView(),
            position: accessoryPosition
        )
    }
}

private func makePreviewAddButton() -> UIButton {
    let button = UIButton(type: .system)
    var configuration = UIButton.Configuration.plain()
    configuration.cornerStyle = .capsule
    configuration.image = UIImage(systemName: "plus")
    configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(scale: .medium)
    button.configuration = configuration
    button.accessibilityLabel = "Add"
    return button
}

#Preview("UIKit") {
    SampleTabBarController(accessoryView: makePreviewAddButton())
}

#Preview("SwiftUI") {
    SampleTabBarControllerPreview {
        makePreviewAddButton()
    }
    .ignoresSafeArea(.all,edges:.vertical)
}
#endif
