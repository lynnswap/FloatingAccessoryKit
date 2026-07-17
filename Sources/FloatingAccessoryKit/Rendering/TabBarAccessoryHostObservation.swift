import UIKit

@MainActor
final class TabBarAccessoryHostObservation {
    private weak var tabBarController: UITabBarController?
    private let observesOverlayInputs: Bool
    private let onChange: @MainActor () -> Void
    private var layoutObservationView: TabBarAccessoryLayoutObservationView?
    private var selectedSafeAreaObservationView: TabBarAccessoryLayoutObservationView?
    private var selectedViewControllerObservation: NSKeyValueObservation?
    private var tabBarFrameObservation: NSKeyValueObservation?
    private var tabBarStandardAppearanceObservation: NSKeyValueObservation?
    private var tabBarScrollEdgeAppearanceObservation: NSKeyValueObservation?
    private var tabBarAppearanceValueObservations: [NSKeyValueObservation] = []
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
            refreshSelectedSafeAreaObservation()
        }
        layoutObservationView?.startObservingChanges()
    }

    isolated deinit {
        layoutObservationView?.removeFromSuperview()
        selectedSafeAreaObservationView?.removeFromSuperview()
    }

    private func installRootGeometryObservation(
        in tabBarController: UITabBarController
    ) {
        let rootView = tabBarController.view!
        let observationView = TabBarAccessoryLayoutObservationView { [weak self] in
            if self?.observesOverlayInputs == true {
                self?.refreshTabBarButtonObservations()
                self?.refreshSelectedSafeAreaObservation()
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
                self?.tabBarAppearanceDidChange()
            }
        }
        tabBarScrollEdgeAppearanceObservation = tabBar.observe(
            \.scrollEdgeAppearance,
            options: [.new]
        ) { [weak self] _, _ in
            MainActor.assumeIsolated {
                self?.tabBarAppearanceDidChange()
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
        refreshTabBarAppearanceValueObservations()
        refreshTabBarButtonObservations()
    }

    private func tabBarAppearanceDidChange() {
        refreshTabBarAppearanceValueObservations()
        onChange()
    }

    private func refreshTabBarAppearanceValueObservations() {
        tabBarAppearanceValueObservations.forEach { $0.invalidate() }
        tabBarAppearanceValueObservations.removeAll()

        guard let tabBar = tabBarController?.tabBar else {
            return
        }

        let standardAppearance = tabBar.standardAppearance
        var appearances = [standardAppearance]
        if let scrollEdgeAppearance = tabBar.scrollEdgeAppearance,
           scrollEdgeAppearance !== standardAppearance {
            appearances.append(scrollEdgeAppearance)
        }

        tabBarAppearanceValueObservations = appearances.flatMap { appearance in
            [
                appearance.observe(\.backgroundColor, options: [.new]) {
                    [weak self] _, _ in
                    MainActor.assumeIsolated {
                        self?.onChange()
                    }
                },
                appearance.observe(\.backgroundEffect, options: [.new]) {
                    [weak self] _, _ in
                    MainActor.assumeIsolated {
                        self?.onChange()
                    }
                }
            ]
        }
    }

    private func hostStructureDidChange() {
        if observesOverlayInputs {
            refreshTabBarButtonObservations()
            refreshSelectedSafeAreaObservation()
        }
        onChange()
    }

    private func refreshSelectedSafeAreaObservation() {
        guard let selectedView = tabBarController?.selectedViewController?.view
        else {
            selectedSafeAreaObservationView?.removeFromSuperview()
            selectedSafeAreaObservationView = nil
            return
        }

        guard selectedSafeAreaObservationView?.superview !== selectedView else {
            return
        }

        selectedSafeAreaObservationView?.removeFromSuperview()
        let observationView = TabBarAccessoryLayoutObservationView { [weak self] in
            self?.onChange()
        }
        observationView.frame = selectedView.bounds
        observationView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        selectedView.insertSubview(observationView, at: 0)
        observationView.startObservingChanges()
        selectedSafeAreaObservationView = observationView
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
        selectedSafeAreaObservationView?.removeFromSuperview()
        selectedSafeAreaObservationView = nil
        selectedViewControllerObservation?.invalidate()
        selectedViewControllerObservation = nil
        tabBarFrameObservation?.invalidate()
        tabBarFrameObservation = nil
        tabBarStandardAppearanceObservation?.invalidate()
        tabBarStandardAppearanceObservation = nil
        tabBarScrollEdgeAppearanceObservation?.invalidate()
        tabBarScrollEdgeAppearanceObservation = nil
        tabBarAppearanceValueObservations.forEach { $0.invalidate() }
        tabBarAppearanceValueObservations.removeAll()
        tabBarVisibilityObservation?.invalidate()
        tabBarVisibilityObservation = nil
        viewControllersObservation?.invalidate()
        viewControllersObservation = nil
        tabBarButtonObservations.forEach { $0.invalidate() }
        tabBarButtonObservations.removeAll()
        observedTabBarButtonIDs.removeAll()
    }
}
