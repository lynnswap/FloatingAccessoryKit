import ObjectiveC
import UIKit

@MainActor
public extension UIViewController {
    /// The items installed with
    /// ``setFloatingAccessoryItems(_:primaryItem:animated:)``.
    var floatingAccessoryItems: [UIBarButtonItem] {
        floatingAccessoryItemsCoordinator?.items ?? []
    }

    /// Shows accessory items in this view controller's own bars.
    ///
    /// Use this method for a view controller that is shown without a tab bar.
    /// For the view controllers of a tab bar controller, use
    /// ``TabBarAccessoryController/setItems(_:primaryItem:position:animated:)``
    /// instead.
    ///
    /// FloatingAccessoryKit picks the bar from the horizontal size class and
    /// moves the items when the size class changes:
    ///
    /// - In a compact width, every item appears in the toolbar of the
    ///   enclosing navigation controller. FloatingAccessoryKit shows the
    ///   toolbar when it is hidden.
    /// - In a regular width, `primaryItem` appears at the trailing side of the
    ///   navigation bar and the other items go to the bar's overflow menu.
    ///   Without a primary item, every item appears in the navigation bar.
    ///
    /// While items are installed, FloatingAccessoryKit owns this view
    /// controller's `toolbarItems` and its navigation item's
    /// `additionalOverflowItems`, and adds a group to the navigation item's
    /// `trailingItemGroups`. Removing the items restores them.
    ///
    /// - Parameters:
    ///   - items: The items to show, in layout order. Pass an empty array to
    ///     remove the items.
    ///   - primaryItem: The item among `items` that stays visible where only
    ///     one item fits.
    ///   - animated: Pass `true` to animate the change where the bar supports
    ///     it.
    func setFloatingAccessoryItems(
        _ items: [UIBarButtonItem],
        primaryItem: UIBarButtonItem? = nil,
        animated: Bool = false
    ) {
        guard !items.isEmpty else {
            floatingAccessoryItemsCoordinator?.remove(animated: animated)
            floatingAccessoryItemsCoordinator = nil
            return
        }

        let coordinator = floatingAccessoryItemsCoordinator
            ?? ViewControllerAccessoryItemsCoordinator(viewController: self)
        floatingAccessoryItemsCoordinator = coordinator
        coordinator.setItems(items, primaryItem: primaryItem, animated: animated)
    }
}

@MainActor
private enum FloatingAccessoryItemsAssociationKey {
    static var coordinator: UInt8 = 0
}

@MainActor
private extension UIViewController {
    var floatingAccessoryItemsCoordinator: ViewControllerAccessoryItemsCoordinator? {
        get {
            objc_getAssociatedObject(
                self,
                &FloatingAccessoryItemsAssociationKey.coordinator
            ) as? ViewControllerAccessoryItemsCoordinator
        }
        set {
            objc_setAssociatedObject(
                self,
                &FloatingAccessoryItemsAssociationKey.coordinator,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
}

/// Keeps a view controller's accessory items in the bar that matches its
/// horizontal size class.
@MainActor
private final class ViewControllerAccessoryItemsCoordinator {
    private weak var viewController: UIViewController?
    private(set) var items: [UIBarButtonItem] = []
    private weak var primaryItem: UIBarButtonItem?
    private var installation: SystemBarItemsInstallation?
    private var traitRegistration: (any UITraitChangeRegistration)?

    init(viewController: UIViewController) {
        self.viewController = viewController
        traitRegistration = viewController.registerForTraitChanges(
            [UITraitHorizontalSizeClass.self]
        ) { [weak self] (_: UIViewController, _: UITraitCollection) in
            self?.install(animated: false)
        }
    }

    func setItems(
        _ items: [UIBarButtonItem],
        primaryItem: UIBarButtonItem?,
        animated: Bool
    ) {
        self.items = items
        self.primaryItem = primaryItem
        install(animated: animated)
    }

    func remove(animated: Bool) {
        installation?.uninstall(animated: animated)
        installation = nil
        items = []
        if let viewController, let traitRegistration {
            viewController.unregisterForTraitChanges(traitRegistration)
        }
        traitRegistration = nil
    }

    private func install(animated: Bool) {
        guard let viewController, !items.isEmpty else {
            return
        }

        let placement: SystemBarItemsInstallation.Placement =
            viewController.traitCollection.horizontalSizeClass == .regular
                ? .navigationBar
                : .toolbar
        if installation?.placement != placement {
            installation?.uninstall(animated: false)
            installation = SystemBarItemsInstallation(
                viewController: viewController,
                placement: placement
            )
        }
        installation?.install(items, primaryItem: primaryItem, animated: animated)
    }
}
