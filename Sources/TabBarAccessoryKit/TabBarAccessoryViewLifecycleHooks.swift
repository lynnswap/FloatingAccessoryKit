import ObjectiveC
import UIKit

@MainActor
@available(iOS 26.0, *)
enum TabBarAccessoryViewLifecycleHooks {
    private typealias NoArgumentIMP = @convention(c) (UITabBarController, Selector) -> Void
    private typealias BoolArgumentIMP = @convention(c) (UITabBarController, Selector, Bool) -> Void

    private static var didInstall = false
    private static var originalViewDidLayoutSubviews: NoArgumentIMP?
    private static var originalViewSafeAreaInsetsDidChange: NoArgumentIMP?
    private static var originalViewDidAppear: BoolArgumentIMP?
    private static var viewDidLayoutSubviewsBlock: Any?
    private static var viewSafeAreaInsetsDidChangeBlock: Any?
    private static var viewDidAppearBlock: Any?
    private static var entries: [Entry] = []

    static func register(_ coordinator: TabBarAccessoryCoordinator, for tabBarController: UITabBarController) {
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
        swizzleViewDidAppear()
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

    private static func swizzleViewDidAppear() {
        let selector = #selector(UIViewController.viewDidAppear(_:))
        guard let method = class_getInstanceMethod(UITabBarController.self, selector) else {
            return
        }

        originalViewDidAppear = unsafeBitCast(method_getImplementation(method), to: BoolArgumentIMP.self)
        let block: @convention(block) (UITabBarController, Bool) -> Void = { tabBarController, animated in
            MainActor.assumeIsolated {
                originalViewDidAppear?(tabBarController, selector, animated)
                updateRegisteredCoordinators(for: tabBarController)
            }
        }
        viewDidAppearBlock = block
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

    private static func pruneEntries() {
        entries.removeAll { $0.tabBarController == nil || $0.coordinator == nil }
    }

    private struct Entry {
        weak var tabBarController: UITabBarController?
        weak var coordinator: TabBarAccessoryCoordinator?
    }
}
