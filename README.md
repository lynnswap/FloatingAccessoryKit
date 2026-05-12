# FloatingAccessoryKit

`FloatingAccessoryKit` makes it simple to add floating accessories to UIKit containers. It currently provides a tab bar accessory controller for `UITabBarController`.

Use any `UIView` as the accessory. On iOS 26+, it uses UIKit's native `UITabAccessory`. On iOS 18, it keeps the accessory positioned with the tab bar.

> [!WARNING]
> This package relies on undocumented APIs and runtime behavior, so extra care is needed before using it in App Store-bound projects.

## Requirements

- iOS 18.0+
- iPhone only
- Swift 6.2

## Usage

```swift
import FloatingAccessoryKit
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

## Accessory Background

The view passed to `setContent` is foreground content. Do not add your own capsule or material background.

On iOS 26+, FloatingAccessoryKit uses the native `UITabAccessory` presentation without adding another background. On iOS 18, FloatingAccessoryKit adds a matching overlay background around the content.

## Tab Bar Minimization

On iOS 26+, use UIKit's `tabBarMinimizeBehavior` when you want the tab bar to minimize while scrolling.

On iOS 18, toggle the tab bar yourself with `setTabBarHidden(_:animated:)`. `FloatingAccessoryKit` keeps the accessory position in sync with the tab bar visibility.
When the tab bar is hidden, tapping or long-pressing the empty area where the tab bar was shown restores it.

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
