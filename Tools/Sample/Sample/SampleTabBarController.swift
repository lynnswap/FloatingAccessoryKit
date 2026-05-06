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
    private let configureAccessory: @MainActor (TabBarAccessoryController) -> Void
    private lazy var accessoryController = TabBarAccessoryController(tabBarController: self)

    init(configureAccessory: @escaping @MainActor (TabBarAccessoryController) -> Void) {
        self.configureAccessory = configureAccessory

        super.init(nibName: nil, bundle: nil)
    }

    convenience init(
        accessoryPosition: TabBarAccessoryController.Position = .trailing,
        accessoryView: @escaping @MainActor () -> UIView
    ) {
        self.init { accessoryController in
            accessoryController.setContent(
                accessoryView(),
                position: accessoryPosition
            )
        }
    }

    convenience init<Accessory: SwiftUI.View>(
        accessoryPosition: TabBarAccessoryController.Position = .trailing,
        @SwiftUI.ViewBuilder accessory: @escaping @MainActor () -> Accessory
    ) {
        self.init { accessoryController in
            accessoryController.setContent(position: accessoryPosition) {
                accessory()
            }
        }
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

        configureAccessory(accessoryController)
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
#Preview("UIView") {
    SampleTabBarController(accessoryView: {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.plain()
        configuration.cornerStyle = .capsule
        configuration.image = UIImage(systemName: "plus")
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(scale: .medium)
        button.configuration = configuration
        button.accessibilityLabel = "Add"
        return button
    })
}

#Preview("SwiftUI") {
    SampleTabBarController {
        Button {} label: {
            Image(systemName: "plus")
        }
    }
}
#endif
