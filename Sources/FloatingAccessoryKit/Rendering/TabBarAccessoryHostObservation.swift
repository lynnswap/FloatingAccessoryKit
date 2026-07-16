import UIKit

@MainActor
final class TabBarAccessoryHostObservation {
    private weak var tabBarController: UITabBarController?
    private let observesOverlayInputs: Bool
    private let onChange: @MainActor () -> Void
    private var layoutObservationView: TabBarAccessoryLayoutObservationView?
    private var selectedViewControllerObservation: NSKeyValueObservation?
    private var tabBarFrameObservation: NSKeyValueObservation?
    private var tabBarStandardAppearanceObservation: NSKeyValueObservation?
    private var tabBarScrollEdgeAppearanceObservation: NSKeyValueObservation?
    private var tabBarVisibilityObservation: NSKeyValueObservation?
    private var viewControllersObservation: NSKeyValueObservation?
    private var tabBarButtonObservations: [NSKeyValueObservation] = []
    private var observedTabBarButtonIDs: Set<ObjectIdentifier> = []

    init(
        tabBarController: UITabBarController,
        observesOverlayInputs: Bool,
        onChange: @escaping @MainActor () -> Void
    ) {
        self.tabBarController = tabBarController
        self.observesOverlayInputs = observesOverlayInputs
        self.onChange = onChange

        installRootGeometryObservation(in: tabBarController)
        installSelectionObservation(in: tabBarController)
        if observesOverlayInputs {
            installOverlayInputObservations(in: tabBarController)
        }
        layoutObservationView?.startObservingChanges()
    }

    private func installRootGeometryObservation(
        in tabBarController: UITabBarController
    ) {
        let rootView = tabBarController.view!
        let observationView = TabBarAccessoryLayoutObservationView { [weak self] in
            if self?.observesOverlayInputs == true {
                self?.refreshTabBarButtonObservations()
            }
            self?.onChange()
        }
        observationView.frame = rootView.bounds
        observationView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        rootView.addSubview(observationView)
        rootView.setNeedsLayout()
        layoutObservationView = observationView
    }

    private func installSelectionObservation(
        in tabBarController: UITabBarController
    ) {
        selectedViewControllerObservation = tabBarController.observe(
            \.selectedViewController,
            options: [.new]
        ) { [weak self] _, _ in
            MainActor.assumeIsolated {
                self?.hostStructureDidChange()
            }
        }
    }

    private func installOverlayInputObservations(
        in tabBarController: UITabBarController
    ) {
        let tabBar = tabBarController.tabBar
        tabBarFrameObservation = tabBar.observe(
            \.frame,
            options: [.new]
        ) { [weak self] _, _ in
            MainActor.assumeIsolated {
                self?.hostStructureDidChange()
            }
        }
        tabBarStandardAppearanceObservation = tabBar.observe(
            \.standardAppearance,
            options: [.new]
        ) { [weak self] _, _ in
            MainActor.assumeIsolated {
                self?.onChange()
            }
        }
        tabBarScrollEdgeAppearanceObservation = tabBar.observe(
            \.scrollEdgeAppearance,
            options: [.new]
        ) { [weak self] _, _ in
            MainActor.assumeIsolated {
                self?.onChange()
            }
        }
        tabBarVisibilityObservation = tabBar.observe(
            \.isHidden,
            options: [.new]
        ) { [weak self] _, _ in
            MainActor.assumeIsolated {
                self?.onChange()
            }
        }
        viewControllersObservation = tabBarController.observe(
            \.viewControllers,
            options: [.new]
        ) { [weak self] _, _ in
            MainActor.assumeIsolated {
                self?.hostStructureDidChange()
            }
        }
        refreshTabBarButtonObservations()
    }

    private func hostStructureDidChange() {
        if observesOverlayInputs {
            refreshTabBarButtonObservations()
        }
        onChange()
    }

    private func refreshTabBarButtonObservations() {
        guard let tabBarController else {
            return
        }

        let buttonViews = TabBarAccessoryTabBarButtons.views(
            in: tabBarController.tabBar
        )
        let buttonIDs = Set(buttonViews.map(ObjectIdentifier.init))
        guard buttonIDs != observedTabBarButtonIDs else {
            return
        }

        observedTabBarButtonIDs = buttonIDs
        tabBarButtonObservations = buttonViews.flatMap { buttonView in
            [
                buttonView.observe(\.frame, options: [.new]) { [weak self] _, _ in
                    MainActor.assumeIsolated {
                        self?.onChange()
                    }
                },
                buttonView.observe(\.isHidden, options: [.new]) { [weak self] _, _ in
                    MainActor.assumeIsolated {
                        self?.onChange()
                    }
                },
                buttonView.observe(\.alpha, options: [.new]) { [weak self] _, _ in
                    MainActor.assumeIsolated {
                        self?.onChange()
                    }
                }
            ]
        }
    }

    func invalidate() {
        layoutObservationView?.removeFromSuperview()
        layoutObservationView = nil
        selectedViewControllerObservation?.invalidate()
        selectedViewControllerObservation = nil
        tabBarFrameObservation?.invalidate()
        tabBarFrameObservation = nil
        tabBarStandardAppearanceObservation?.invalidate()
        tabBarStandardAppearanceObservation = nil
        tabBarScrollEdgeAppearanceObservation?.invalidate()
        tabBarScrollEdgeAppearanceObservation = nil
        tabBarVisibilityObservation?.invalidate()
        tabBarVisibilityObservation = nil
        viewControllersObservation?.invalidate()
        viewControllersObservation = nil
        tabBarButtonObservations.forEach { $0.invalidate() }
        tabBarButtonObservations.removeAll()
        observedTabBarButtonIDs.removeAll()
    }
}
