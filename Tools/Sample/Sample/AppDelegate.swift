//
//  AppDelegate.swift
//  Sample
//
//  Created by Kazuki Nakashima on 2026/05/06.
//

import FloatingAccessoryKit
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Launch with `-UseTabAccessory YES` to compare against the
        // UITabAccessory presentation.
        TabBarAccessoryController.attachesToTabBarGlassGroup =
            !UserDefaults.standard.bool(forKey: "UseTabAccessory")
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}
