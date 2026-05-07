import ObjectiveC
import UIKit

@MainActor
enum TabBarAccessoryViewLifecycleHooks {
    private typealias NoArgumentIMP = @convention(c) (UITabBarController, Selector) -> Void
    private typealias BoolArgumentIMP = @convention(c) (UITabBarController, Selector, Bool) -> Void
    private typealias SetTabBarHiddenIMP = @convention(c) (UITabBarController, Selector, Bool, Bool) -> Void

    private static var didInstall = false
    private static var originalViewDidLayoutSubviews: NoArgumentIMP?
    private static var originalViewSafeAreaInsetsDidChange: NoArgumentIMP?
    private static var originalViewIsAppearing: BoolArgumentIMP?
    private static var originalSetTabBarHidden: SetTabBarHiddenIMP?
    private static var viewDidLayoutSubviewsBlock: Any?
    private static var viewSafeAreaInsetsDidChangeBlock: Any?
    private static var viewIsAppearingBlock: Any?
    private static var setTabBarHiddenBlock: Any?
    private static var entries: [Entry] = []

    static func register(
        _ coordinator: any TabBarAccessoryCoordinating,
        for tabBarController: UITabBarController
    ) {
        installIfNeeded()
        pruneEntries()
        guard !entries.contains(where: { $0.coordinator === coordinator }) else {
            return
        }
        entries.append(Entry(tabBarController: tabBarController, coordinator: coordinator))
    }

    private static func installIfNeeded() {
        guard !didInstall else {
            return
        }

        didInstall = true
        swizzleViewDidLayoutSubviews()
        swizzleViewSafeAreaInsetsDidChange()
        swizzleViewIsAppearing()
        swizzleSetTabBarHidden()
    }

    private static func swizzleViewDidLayoutSubviews() {
        let selector = #selector(UIViewController.viewDidLayoutSubviews)
        guard let method = class_getInstanceMethod(UITabBarController.self, selector) else {
            return
        }

        originalViewDidLayoutSubviews = unsafeBitCast(method_getImplementation(method), to: NoArgumentIMP.self)
        let block: @convention(block) (UITabBarController) -> Void = { tabBarController in
            MainActor.assumeIsolated {
                originalViewDidLayoutSubviews?(tabBarController, selector)
                updateRegisteredCoordinators(for: tabBarController)
            }
        }
        viewDidLayoutSubviewsBlock = block
        let implementation = imp_implementationWithBlock(block)
        if !class_addMethod(UITabBarController.self, selector, implementation, method_getTypeEncoding(method)) {
            method_setImplementation(method, implementation)
        }
    }

    private static func swizzleViewSafeAreaInsetsDidChange() {
        let selector = #selector(UIViewController.viewSafeAreaInsetsDidChange)
        guard let method = class_getInstanceMethod(UITabBarController.self, selector) else {
            return
        }

        originalViewSafeAreaInsetsDidChange = unsafeBitCast(method_getImplementation(method), to: NoArgumentIMP.self)
        let block: @convention(block) (UITabBarController) -> Void = { tabBarController in
            MainActor.assumeIsolated {
                originalViewSafeAreaInsetsDidChange?(tabBarController, selector)
                updateRegisteredCoordinators(for: tabBarController)
            }
        }
        viewSafeAreaInsetsDidChangeBlock = block
        let implementation = imp_implementationWithBlock(block)
        if !class_addMethod(UITabBarController.self, selector, implementation, method_getTypeEncoding(method)) {
            method_setImplementation(method, implementation)
        }
    }

    private static func swizzleViewIsAppearing() {
        let selector = #selector(UIViewController.viewIsAppearing(_:))
        guard let method = class_getInstanceMethod(UITabBarController.self, selector) else {
            return
        }

        originalViewIsAppearing = unsafeBitCast(method_getImplementation(method), to: BoolArgumentIMP.self)
        let block: @convention(block) (UITabBarController, Bool) -> Void = { tabBarController, animated in
            MainActor.assumeIsolated {
                originalViewIsAppearing?(tabBarController, selector, animated)
                updateRegisteredCoordinators(for: tabBarController)
            }
        }
        viewIsAppearingBlock = block
        let implementation = imp_implementationWithBlock(block)
        if !class_addMethod(UITabBarController.self, selector, implementation, method_getTypeEncoding(method)) {
            method_setImplementation(method, implementation)
        }
    }

    private static func swizzleSetTabBarHidden() {
        let selector = #selector(UITabBarController.setTabBarHidden(_:animated:))
        guard let method = class_getInstanceMethod(UITabBarController.self, selector) else {
            return
        }

        originalSetTabBarHidden = unsafeBitCast(method_getImplementation(method), to: SetTabBarHiddenIMP.self)
        let block: @convention(block) (UITabBarController, Bool, Bool) -> Void = { tabBarController, hidden, animated in
            MainActor.assumeIsolated {
                originalSetTabBarHidden?(tabBarController, selector, hidden, animated)
                notifyTabBarVisibilityDidChange(hidden: hidden, animated: animated, for: tabBarController)
            }
        }
        setTabBarHiddenBlock = block
        let implementation = imp_implementationWithBlock(block)
        if !class_addMethod(UITabBarController.self, selector, implementation, method_getTypeEncoding(method)) {
            method_setImplementation(method, implementation)
        }
    }

    private static func updateRegisteredCoordinators(for tabBarController: UITabBarController) {
        pruneEntries()
        entries
            .filter { $0.tabBarController === tabBarController }
            .forEach { $0.coordinator?.update(in: tabBarController) }
    }

    private static func notifyTabBarVisibilityDidChange(
        hidden: Bool,
        animated: Bool,
        for tabBarController: UITabBarController
    ) {
        pruneEntries()
        entries
            .filter { $0.tabBarController === tabBarController }
            .forEach {
                $0.coordinator?.tabBarVisibilityDidChange(
                    hidden: hidden,
                    animated: animated,
                    in: tabBarController
                )
            }
    }

    private static func pruneEntries() {
        entries.removeAll { $0.tabBarController == nil || $0.coordinator == nil }
    }

    private struct Entry {
        weak var tabBarController: UITabBarController?
        weak var coordinator: (any TabBarAccessoryCoordinating)?
    }
}
