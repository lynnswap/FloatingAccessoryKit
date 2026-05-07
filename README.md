# TabBarAccessoryKit

`TabBarAccessoryKit` makes it simple to add a floating action button to a `UITabBarController`.

Use any `UIView` as the accessory. On iOS 26+, it uses UIKit's native `UITabAccessory`. On iOS 18, it keeps the accessory positioned with the tab bar.

> [!WARNING]
> This package relies on undocumented APIs and runtime behavior, so extra care is needed before using it in App Store-bound projects.

## Requirements

- iOS 18.0+
- iPhone only
- Swift 6.2

## Usage

```swift
import TabBarAccessoryKit
import UIKit

final class MainTabBarController: UITabBarController {
    private lazy var accessoryController = TabBarAccessoryController(
        tabBarController: self
    )

    override func viewDidLoad() {
        super.viewDidLoad()

        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "plus"), for: .normal)

        accessoryController.setContent(
            button,
            position: .trailing,
            animated: false
        )
    }
}
```

## Tab Bar Minimization

On iOS 26+, use UIKit's `tabBarMinimizeBehavior` when you want the tab bar to minimize while scrolling.

On iOS 18, toggle the tab bar yourself with `setTabBarHidden(_:animated:)`. `TabBarAccessoryKit` keeps the accessory position in sync with the tab bar visibility.

```swift
if #available(iOS 26.0, *) {
    tabBarMinimizeBehavior = .onScrollDown
}
```

For iOS 18, implement your own scroll policy, then call `setTabBarHidden(_:animated:)` when that policy decides to hide or show the tab bar.

```swift
func scrollViewDidScroll(_ scrollView: UIScrollView) {
    guard #unavailable(iOS 26.0) else {
        return
    }

    setTabBarHidden(shouldHideTabBar, animated: true)
}
```
