# FloatingAccessoryKit

`FloatingAccessoryKit` makes it simple to add floating accessories to UIKit containers. It currently provides a tab bar accessory controller for `UITabBarController`.

Use a `UIView` whose intrinsic content size, internal Auto Layout constraints, or nonzero bounds describe its fitting size. On iOS 26+, FloatingAccessoryKit uses UIKit's native `UITabAccessory`. On iOS 18, it keeps the accessory positioned with the tab bar.

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
    override func viewDidLoad() {
        super.viewDidLoad()

        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "plus"), for: .normal)

        floatingAccessoryController.setContentView(
            button,
            position: .trailing,
            animated: false
        )
    }
}
```

## Accessory Background

The view passed to `setContentView` is foreground content. Do not add your own capsule or material background.

On iOS 26+, FloatingAccessoryKit uses the native `UITabAccessory` presentation without adding another background. On iOS 18, FloatingAccessoryKit adds a matching overlay background around the content.

## Tab Bar Minimization

On iOS 26+, use UIKit's `tabBarMinimizeBehavior` when you want the tab bar to minimize while scrolling.

On iOS 18, toggle the tab bar through `floatingAccessoryController.setTabBarHidden(_:animated:)`. `FloatingAccessoryKit` then updates the accessory and the tab bar from the same coordination boundary.
When the tab bar is hidden, tapping or long-pressing the empty area where the tab bar was shown restores it.

```swift
if #available(iOS 26.0, *) {
    tabBarMinimizeBehavior = .onScrollDown
}
```

For iOS 18, implement your own scroll policy, then call `floatingAccessoryController.setTabBarHidden(_:animated:)` when that policy decides to hide or show the tab bar.

```swift
func scrollViewDidScroll(_ scrollView: UIScrollView) {
    guard #unavailable(iOS 26.0) else {
        return
    }

    floatingAccessoryController.setTabBarHidden(
        shouldHideTabBar,
        animated: true
    )
}
```

## Migration

### v0.3.0

These notes apply when upgrading from `v0.2.x` or earlier to `v0.3.0`.

- Replace `TabBarAccessoryController(tabBarController:)` with the controller owned by the host:

  ```swift
  let accessoryController = tabBarController.floatingAccessoryController
  ```

- Replace `setContent(_:position:animated:)` with the operation that matches the change:

  ```swift
  accessoryController.setContentView(view, position: .trailing, animated: true)
  accessoryController.setPosition(.center, animated: true)
  accessoryController.setHidden(true, animated: true)
  accessoryController.removeContent(animated: true)
  ```

- `position` and `isHidden` now remain unchanged when content is removed. Installing content without a `position` also preserves the current position.
- Content-size changes are observed automatically. Do not resubmit the same view just to trigger measurement.
- `removeContent(animated:)` detaches the consumer view before returning. Any remaining removal animation uses a snapshot.
- On iOS 18, replace direct calls to `UITabBarController.setTabBarHidden(_:animated:)` with `floatingAccessoryController.setTabBarHidden(_:animated:)` so the overlay is updated in the same operation.
