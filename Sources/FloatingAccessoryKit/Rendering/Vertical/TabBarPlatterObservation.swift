import UIKit

/// Tracks the glass platters that UIKit draws for a tab bar.
///
/// UIKit keeps one platter for the expanded tab bar and another for the
/// minimized one, and hides whichever is not showing. On a vertical tab bar the
/// platter lives outside `UITabBar`, so platters are discovered below the tab
/// bar controller's view rather than below the tab bar.
@MainActor
@available(iOS 26.0, *)
final class TabBarPlatterObservation {
    private static let platterClassNames: Set<String> = [
        ["_UITabBar", "ItemPlatterView"].joined(),
        ["_UITabBar", "PlatterView"].joined()
    ]

    private let onChange: @MainActor () -> Void
    private var platters: [UIView] = []
    private var observations: [NSKeyValueObservation] = []
    private weak var mostRecentlyShownPlatter: UIView?

    init(onChange: @escaping @MainActor () -> Void) {
        self.onChange = onChange
    }

    /// The platter the tab bar is showing, or moving toward during a
    /// minimize or expand transition.
    var currentPlatter: UIView? {
        let visiblePlatters = platters.filter(Self.isVisible)
        if let mostRecentlyShownPlatter,
           visiblePlatters.contains(where: { $0 === mostRecentlyShownPlatter }) {
            return mostRecentlyShownPlatter
        }
        return visiblePlatters.first
    }

    func refresh(in tabBarController: UITabBarController) {
        var discovered: [UIView] = []
        let contentView = tabBarController.selectedViewController?.viewIfLoaded
        for subview in tabBarController.view.subviews {
            if let contentView,
               contentView.isDescendant(of: subview) {
                continue
            }
            Self.collectPlatters(in: subview, into: &discovered)
        }

        guard !discovered.elementsEqual(platters, by: { $0 === $1 }) else {
            return
        }

        observations.forEach { $0.invalidate() }
        platters = discovered
        observations = discovered.flatMap(makeObservations(for:))
    }

    func invalidate() {
        observations.forEach { $0.invalidate() }
        observations.removeAll()
        platters.removeAll()
        mostRecentlyShownPlatter = nil
    }

    private func makeObservations(
        for platter: UIView
    ) -> [NSKeyValueObservation] {
        [
            platter.observe(\.isHidden, options: [.new]) { [weak self] platter, change in
                MainActor.assumeIsolated {
                    if change.newValue == false {
                        self?.mostRecentlyShownPlatter = platter
                    }
                    self?.onChange()
                }
            },
            platter.observe(\.alpha, options: [.new]) { [weak self] _, _ in
                MainActor.assumeIsolated {
                    self?.onChange()
                }
            },
            platter.layer.observe(\.bounds, options: [.new]) { [weak self] _, _ in
                MainActor.assumeIsolated {
                    self?.onChange()
                }
            },
            platter.layer.observe(\.position, options: [.new]) { [weak self] _, _ in
                MainActor.assumeIsolated {
                    self?.onChange()
                }
            }
        ]
    }

    private static func collectPlatters(
        in view: UIView,
        into platters: inout [UIView]
    ) {
        if platterClassNames.contains(String(describing: type(of: view))) {
            platters.append(view)
            return
        }
        for subview in view.subviews {
            collectPlatters(in: subview, into: &platters)
        }
    }

    private static func isVisible(_ platter: UIView) -> Bool {
        platter.window != nil
            && !platter.isHidden
            && platter.alpha > 0.01
            && !platter.bounds.isEmpty
    }
}
