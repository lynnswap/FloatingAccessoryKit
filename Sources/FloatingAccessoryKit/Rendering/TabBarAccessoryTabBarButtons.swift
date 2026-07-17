import UIKit

@MainActor
enum TabBarAccessoryTabBarButtons {
    private static let legacyClassName = ["Button", "Bar", "Tab", "UI"]
        .reversed()
        .joined()

    static func views(in tabBar: UITabBar) -> [UIView] {
        let classes = [legacyClassName].compactMap(NSClassFromString)
        return tabBar.subviews.filter { view in
            classes.contains { view.isKind(of: $0) }
        }
    }

    static func maximumVisibleHeight(in tabBar: UITabBar) -> CGFloat? {
        views(in: tabBar)
            .compactMap { view -> CGFloat? in
                guard !view.isHidden,
                      view.alpha > 0.01,
                      view.bounds.height.isFinite,
                      view.bounds.height > 0 else {
                    return nil
                }

                return view.bounds.height
            }
            .max()
    }
}
