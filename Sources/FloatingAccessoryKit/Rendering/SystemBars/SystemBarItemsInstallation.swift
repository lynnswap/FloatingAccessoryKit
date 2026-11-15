import UIKit

/// Shows accessory items in one of a view controller's own system bars, and
/// puts the bar back the way it was when the items leave.
@MainActor
final class SystemBarItemsInstallation {
    enum Placement: Equatable {
        /// The toolbar, with every item in it.
        case toolbar
        /// The toolbar that UIKit lays out next to a vertical tab bar. The
        /// primary item stands out and the other items share a menu.
        case verticalToolbar
        /// The trailing side of the navigation bar. The primary item is shown
        /// and the other items go to the bar's overflow menu.
        case navigationBar
    }

    /// Whether the items can go next to a vertical tab bar.
    ///
    /// The bar needs `UIBarButtonItem.axisBehavior` from the iOS 27.1 SDK.
    /// Xcode 27.2 has the first compiler version that tells that SDK apart
    /// from the iOS 27.0 SDK.
    static var supportsVerticalToolbar: Bool {
        #if compiler(>=6.4.2)
        if #available(iOS 27.1, *) {
            return true
        }
        #endif
        return false
    }

    private(set) weak var viewController: UIViewController?
    let placement: Placement

    private var isInstalled = false
    private var originalToolbarItems: [UIBarButtonItem]?
    private var revealedToolbar: UINavigationController?
    private var originalAdditionalOverflowItems: UIDeferredMenuElement?
    private var trailingGroup: UIBarButtonItemGroup?
    private var itemRestorations: [@MainActor () -> Void] = []

    init(viewController: UIViewController, placement: Placement) {
        self.viewController = viewController
        self.placement = placement
    }

    func install(
        _ items: [UIBarButtonItem],
        primaryItem: UIBarButtonItem?,
        animated: Bool
    ) {
        guard let viewController else {
            return
        }

        let primaryItem = primaryItem.flatMap { primaryItem in
            items.contains { $0 === primaryItem } ? primaryItem : nil
        }
        let otherItems = items.filter { $0 !== primaryItem }
        restoreItems()

        switch placement {
        case .toolbar:
            setToolbarItems(items, of: viewController, animated: animated)
        case .verticalToolbar:
            var barItems = items
            if let primaryItem {
                let originalStyle = primaryItem.style
                itemRestorations.append { primaryItem.style = originalStyle }
                if #available(iOS 26.0, *) {
                    primaryItem.style = .prominent
                }
                barItems = [primaryItem]
                if !otherItems.isEmpty {
                    let overflowItem = Self.makeOverflowItem(for: otherItems)
                    if items.first === primaryItem {
                        barItems.append(overflowItem)
                    } else {
                        barItems.insert(overflowItem, at: 0)
                    }
                }
            }
            #if compiler(>=6.4.2)
            if #available(iOS 27.1, *) {
                for item in barItems {
                    let originalAxisBehavior = item.axisBehavior
                    itemRestorations.append { item.axisBehavior = originalAxisBehavior }
                    item.axisBehavior = .verticalPreferred
                }
            }
            #endif
            setToolbarItems(barItems, of: viewController, animated: animated)
        case .navigationBar:
            let navigationItem = viewController.navigationItem
            if !isInstalled {
                originalAdditionalOverflowItems = navigationItem.additionalOverflowItems
            }
            let group = UIBarButtonItemGroup.fixedGroup(
                items: primaryItem.map { [$0] } ?? items
            )
            navigationItem.trailingItemGroups = navigationItem.trailingItemGroups
                .filter { $0 !== trailingGroup } + [group]
            trailingGroup = group
            navigationItem.additionalOverflowItems = primaryItem == nil || otherItems.isEmpty
                ? originalAdditionalOverflowItems
                : Self.makeOverflowElement(for: otherItems)
        }
        isInstalled = true
    }

    func uninstall(animated: Bool) {
        guard isInstalled else {
            return
        }

        isInstalled = false
        restoreItems()
        guard let viewController else {
            return
        }

        switch placement {
        case .toolbar, .verticalToolbar:
            viewController.setToolbarItems(originalToolbarItems, animated: animated)
            originalToolbarItems = nil
            revealedToolbar?.setToolbarHidden(true, animated: animated)
            revealedToolbar = nil
        case .navigationBar:
            let navigationItem = viewController.navigationItem
            navigationItem.trailingItemGroups = navigationItem.trailingItemGroups
                .filter { $0 !== trailingGroup }
            trailingGroup = nil
            navigationItem.additionalOverflowItems = originalAdditionalOverflowItems
            originalAdditionalOverflowItems = nil
        }
    }

    private func setToolbarItems(
        _ items: [UIBarButtonItem],
        of viewController: UIViewController,
        animated: Bool
    ) {
        if !isInstalled {
            originalToolbarItems = viewController.toolbarItems
        }
        // The space keeps the items at the trailing end of the toolbar.
        viewController.setToolbarItems([.flexibleSpace()] + items, animated: animated)
        if let navigationController = viewController.navigationController,
           navigationController.isToolbarHidden {
            navigationController.setToolbarHidden(false, animated: animated)
            revealedToolbar = navigationController
        }
    }

    private func restoreItems() {
        for restore in itemRestorations {
            restore()
        }
        itemRestorations = []
    }

    private static func makeOverflowItem(
        for items: [UIBarButtonItem]
    ) -> UIBarButtonItem {
        UIBarButtonItem(
            image: UIImage(systemName: "ellipsis"),
            menu: UIMenu(children: [makeOverflowElement(for: items)])
        )
    }

    /// Reads the items when the menu opens, so the menu follows changes that
    /// the items' owner makes after installation.
    private static func makeOverflowElement(
        for items: [UIBarButtonItem]
    ) -> UIDeferredMenuElement {
        UIDeferredMenuElement.uncached { completion in
            completion(
                items
                    .filter { !$0.isHidden }
                    .compactMap { $0.menuRepresentation ?? makeMenuElement(for: $0) }
            )
        }
    }

    /// A menu element for an item without a menu representation of its own:
    /// its primary action or target-action as an action, or its menu as a
    /// submenu.
    private static func makeMenuElement(for item: UIBarButtonItem) -> UIMenuElement? {
        let primaryAction = item.primaryAction
        let title = [item.title, primaryAction?.title, item.menu?.title, item.accessibilityLabel]
            .compactMap { $0 }
            .first { !$0.isEmpty } ?? ""
        let image = item.image ?? primaryAction?.image ?? item.menu?.image

        if primaryAction == nil, item.action == nil, item.isEnabled {
            return item.menu.map { menu in
                UIMenu(title: title, image: image, children: menu.children)
            }
        }
        // A disabled item stays in the menu as a disabled action, also when
        // it would open a submenu.
        return UIAction(
            title: title,
            image: image,
            attributes: item.isEnabled ? [] : .disabled
        ) { [weak item] _ in
            guard let item else {
                return
            }
            if let primaryAction = item.primaryAction {
                primaryAction.performWithSender(item, target: nil)
            } else if let action = item.action {
                UIApplication.shared.sendAction(
                    action,
                    to: item.target,
                    from: item,
                    for: nil
                )
            }
        }
    }
}
