//
//  SampleTabBarController.swift
//  Sample
//
//  Created by Kazuki Nakashima on 2026/05/06.
//

import TabBarAccessoryKit
import UIKit

final class SampleTabBarController: UITabBarController {
    private lazy var accessoryController = TabBarAccessoryController(tabBarController: self)

    override func viewDidLoad() {
        super.viewDidLoad()

        tabBarMinimizeBehavior = .onScrollDown
        viewControllers = [
            makePreviewTab(title: "Home", systemImageName: "house"),
            makePreviewTab(title: "Settings", systemImageName: "gearshape")
        ]

        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "plus"), for: .normal)
        button.accessibilityLabel = "Add"
        accessoryController.setContent(button)
    }

    private func makePreviewTab(title: String, systemImageName: String) -> UIViewController {
        let viewController = PreviewScrollViewController()
        viewController.title = title
        viewController.tabBarItem = UITabBarItem(
            title: title,
            image: UIImage(systemName: systemImageName),
            selectedImage: nil
        )
        return viewController
    }
}

private final class PreviewScrollViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        configureScrollView()
        addPreviewBlocks()
    }

    private func configureScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 0

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }

    private func addPreviewBlocks() {
        [
            UIColor.black,
            UIColor.systemMint.withAlphaComponent(0.1),
            UIColor.black
        ].forEach { color in
            let blockView = UIView()
            blockView.backgroundColor = color
            blockView.translatesAutoresizingMaskIntoConstraints = false
            stackView.addArrangedSubview(blockView)
            blockView.heightAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.heightAnchor,
                multiplier: 0.6
            ).isActive = true
        }
    }
}
