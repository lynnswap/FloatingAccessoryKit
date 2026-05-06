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

    convenience init<Accessory: SwiftUI.View>(
        accessoryPosition: TabBarAccessoryController.Position = .trailing,
        @SwiftUI.ViewBuilder accessory: @escaping @MainActor () -> Accessory
    ) {
        self.init(accessoryConfiguration: .swiftUI(position: accessoryPosition, accessory: accessory))
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

    func setAccessory<Accessory: SwiftUI.View>(
        position: TabBarAccessoryController.Position = .trailing,
        @SwiftUI.ViewBuilder _ accessory: @escaping @MainActor () -> Accessory
    ) {
        accessoryConfiguration = .swiftUI(position: position, accessory: accessory)
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

    static func swiftUI<Accessory: SwiftUI.View>(
        position: TabBarAccessoryController.Position,
        @SwiftUI.ViewBuilder accessory: @escaping @MainActor () -> Accessory
    ) -> Self {
        AccessoryConfiguration { accessoryController in
            accessoryController.setContent(position: position) {
                accessory()
            }
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

private struct SampleTabBarControllerPreview<Accessory: SwiftUI.View>: UIViewControllerRepresentable {
    private let accessoryPosition: TabBarAccessoryController.Position
    private let accessory: @MainActor () -> Accessory

    init(
        accessoryPosition: TabBarAccessoryController.Position = .trailing,
        @SwiftUI.ViewBuilder accessory: @escaping @MainActor () -> Accessory
    ) {
        self.accessoryPosition = accessoryPosition
        self.accessory = accessory
    }

    func makeUIViewController(context: Context) -> SampleTabBarController {
        SampleTabBarController(accessoryPosition: accessoryPosition) {
            accessory()
        }
    }

    func updateUIViewController(_ uiViewController: SampleTabBarController, context: Context) {
        uiViewController.setAccessory(position: accessoryPosition) {
            accessory()
        }
    }
}

#if DEBUG
#Preview("UIView") {
    let button = UIButton(type: .system)
    var configuration = UIButton.Configuration.plain()
    configuration.cornerStyle = .capsule
    configuration.image = UIImage(systemName: "plus")
    configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(scale: .medium)
    button.configuration = configuration
    button.accessibilityLabel = "Add"

    return SampleTabBarController(accessoryView: button)
}

#Preview("SwiftUI") {
    @Previewable @State var isShowing: Bool = false
    SampleTabBarControllerPreview {
        if isShowing {
            Button {} label: {
                Image(systemName: "minus")
            }
        }
        Button {
            isShowing.toggle()
        } label: {
            Image(systemName: "plus")
        }
        
    }
    .ignoresSafeArea(.all,edges:.vertical)
}
#endif
