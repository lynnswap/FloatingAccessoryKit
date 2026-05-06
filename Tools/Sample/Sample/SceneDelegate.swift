//
//  SceneDelegate.swift
//  Sample
//
//  Created by Kazuki Nakashima on 2026/05/06.
//

import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else {
            return
        }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = SampleTabBarController(accessoryView: {
            Self.makeAddButton()
        })
        window.makeKeyAndVisible()
        self.window = window
    }

    private static func makeAddButton() -> UIButton {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.plain()
        configuration.cornerStyle = .capsule
        configuration.image = UIImage(systemName: "plus")
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(scale: .medium)
        button.configuration = configuration
        button.accessibilityLabel = "Add"
        return button
    }
}
