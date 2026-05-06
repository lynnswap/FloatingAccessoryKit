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
        window.rootViewController = SampleTabBarController()
        window.makeKeyAndVisible()
        self.window = window
    }
}
