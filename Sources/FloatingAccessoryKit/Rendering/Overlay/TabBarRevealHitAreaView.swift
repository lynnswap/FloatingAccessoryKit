import UIKit

@MainActor
final class TabBarRevealHitAreaView: UIView {
    private weak var tabBarController: UITabBarController?

    init(tabBarController: UITabBarController) {
        self.tabBarController = tabBarController

        super.init(frame: .zero)

        backgroundColor = .clear
        accessibilityIdentifier = "FloatingAccessoryKit.TabBarRevealHitArea"
        isAccessibilityElement = true
        accessibilityLabel = "Show Tab Bar"
        accessibilityTraits = .button

        addGestureRecognizer(
            UITapGestureRecognizer(
                target: self,
                action: #selector(handleTap(_:))
            )
        )
        addGestureRecognizer(
            UILongPressGestureRecognizer(
                target: self,
                action: #selector(handleLongPress(_:))
            )
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func accessibilityActivate() -> Bool {
        revealTabBar()
    }

    @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
        revealTabBar()
    }

    @objc func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else {
            return
        }

        revealTabBar()
    }

    @discardableResult
    func revealTabBar() -> Bool {
        guard let tabBarController else {
            return false
        }

        tabBarController.floatingAccessoryController.setTabBarHidden(
            false,
            animated: true
        )
        return true
    }
}
