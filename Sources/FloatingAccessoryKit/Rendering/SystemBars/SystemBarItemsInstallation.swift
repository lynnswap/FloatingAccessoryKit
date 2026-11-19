import ObjectiveC
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
        /// and the other items go to the bar's overflow menu. The app's own
        /// right items keep the trailing edge, next to the overflow button,
        /// and the shown items stand apart on their leading side.
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
    private weak var revealedToolbar: UINavigationController?
    private var originalAdditionalOverflowItems: UIDeferredMenuElement?
    private var trailingGroup: UIBarButtonItemGroup?
    private var overflow: (item: UIBarButtonItem, sources: [UIBarButtonItem])?
    /// The accessory items placed among the app's own `rightBarButtonItems`,
    /// with the separator in front of them.
    /// Assigning `trailingItemGroups` would discard the app's items, so the
    /// accessory items join them instead.
    private var rightBarButtonItems: [UIBarButtonItem]?
    /// The items that the vertical toolbar changed, with what they had before.
    private var itemModifications: [ObjectIdentifier: ItemModification] = [:]
    private let spaceItem = UIBarButtonItem.flexibleSpace()
    /// Splits the background that adjacent navigation bar items share.
    private let separatorItem = UIBarButtonItem.fixedSpace(0)

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

        switch placement {
        case .toolbar:
            setToolbarItems(items, of: viewController, animated: animated)
        case .verticalToolbar:
            var barItems = items
            if let primaryItem {
                barItems = [primaryItem]
                if !otherItems.isEmpty {
                    let overflowItem = overflowItem(for: otherItems)
                    if items.first === primaryItem {
                        barItems.append(overflowItem)
                    } else {
                        barItems.insert(overflowItem, at: 0)
                    }
                }
            }
            modifyItems(barItems, primaryItem: primaryItem)
            // With animation, UIKit builds every item of the bar again, so an
            // item that stays would leave and form again in its place.
            let keepsShownItem = viewController.toolbarItems?.contains { shownItem in
                barItems.contains { $0 === shownItem }
            } == true
            setToolbarItems(
                barItems,
                of: viewController,
                animated: animated && !keepsShownItem
            )
        case .navigationBar:
            let navigationItem = viewController.navigationItem
            if !isInstalled {
                originalAdditionalOverflowItems = navigationItem.additionalOverflowItems
                if navigationItem.trailingItemGroups.isEmpty,
                   navigationItem.rightBarButtonItems?.isEmpty == false {
                    rightBarButtonItems = []
                }
            }
            let shownItems = primaryItem.map { [$0] } ?? items
            if let previousItems = rightBarButtonItems {
                let appItems = (navigationItem.rightBarButtonItems ?? []).filter { item in
                    !previousItems.contains { $0 === item }
                }
                // The first right item is the one at the trailing edge. The
                // bar puts its overflow button at that edge, so the app's
                // items there share its background, and the separator keeps
                // the shown items in a background of their own.
                let accessoryItems = appItems.isEmpty
                    ? shownItems.reversed()
                    : [separatorItem] + shownItems.reversed()
                navigationItem.rightBarButtonItems = appItems + accessoryItems
                rightBarButtonItems = accessoryItems
            } else {
                let group = UIBarButtonItemGroup.fixedGroup(items: shownItems)
                navigationItem.trailingItemGroups = navigationItem.trailingItemGroups
                    .filter { $0 !== trailingGroup } + [group]
                trailingGroup = group
            }
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
        // The toolbar is released also when the view controller is gone.
        if let revealedToolbar {
            RevealedToolbarUsers.remove(from: revealedToolbar, animated: animated)
        }
        revealedToolbar = nil
        guard let viewController else {
            return
        }

        switch placement {
        case .toolbar, .verticalToolbar:
            viewController.setToolbarItems(originalToolbarItems, animated: animated)
            originalToolbarItems = nil
        case .navigationBar:
            let navigationItem = viewController.navigationItem
            // Only the accessory's own items leave, and only while they are
            // still in the bar, so changes the app made meanwhile stay.
            if let rightBarButtonItems {
                let currentItems = navigationItem.rightBarButtonItems ?? []
                let appItems = currentItems.filter { item in
                    !rightBarButtonItems.contains { $0 === item }
                }
                if appItems.count != currentItems.count {
                    navigationItem.rightBarButtonItems = appItems
                }
            } else if navigationItem.trailingItemGroups.contains(where: { $0 === trailingGroup }) {
                navigationItem.trailingItemGroups = navigationItem.trailingItemGroups
                    .filter { $0 !== trailingGroup }
            }
            rightBarButtonItems = nil
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
        // The app's own items keep the leading end, and the space keeps the
        // accessory items at the trailing end.
        let toolbarItems = (originalToolbarItems ?? []) + [spaceItem] + items
        if viewController.toolbarItems?.elementsEqual(toolbarItems, by: { $0 === $1 }) != true {
            viewController.setToolbarItems(toolbarItems, animated: animated)
        }
        if revealedToolbar == nil,
           let navigationController = viewController.navigationController,
           RevealedToolbarUsers.add(to: navigationController, animated: animated) {
            revealedToolbar = navigationController
        }
    }

    /// Gives the items of a vertical toolbar their style and axis, and gives
    /// the items that left what they had before.
    ///
    /// An item that stays is not assigned again. UIKit builds an item's view
    /// again on every assignment, and observes the item's state: assigning
    /// the same values on every pass keeps waking the observations that
    /// follow the bar.
    private func modifyItems(
        _ barItems: [UIBarButtonItem],
        primaryItem: UIBarButtonItem?
    ) {
        // What leaves is restored before anything is assigned, as an
        // assignment to one item can reach another.
        let barItemIDs = Set(barItems.map(ObjectIdentifier.init))
        for (id, modification) in itemModifications where !barItemIDs.contains(id) {
            modification.restore()
            itemModifications[id] = nil
        }
        for item in barItems where item !== primaryItem {
            let id = ObjectIdentifier(item)
            if let originalStyle = itemModifications[id]?.originalStyle {
                item.style = originalStyle
                itemModifications[id]?.originalStyle = nil
            }
        }

        for item in barItems {
            let id = ObjectIdentifier(item)
            var modification = itemModifications[id] ?? ItemModification(item: item)
            if item === primaryItem {
                if modification.originalStyle == nil {
                    modification.originalStyle = item.style
                }
                if #available(iOS 26.0, *), item.style != .prominent {
                    item.style = .prominent
                }
            }
            #if compiler(>=6.4.2)
            if #available(iOS 27.1, *) {
                if modification.originalAxisBehavior == nil {
                    modification.originalAxisBehavior = item.axisBehavior.rawValue
                }
                if item.axisBehavior != .verticalPreferred {
                    item.axisBehavior = .verticalPreferred
                }
            }
            #endif
            itemModifications[id] = modification
        }
    }

    private func restoreItems() {
        for modification in itemModifications.values {
            modification.restore()
        }
        itemModifications = [:]
    }

    @MainActor
    private struct ItemModification {
        let item: UIBarButtonItem
        var originalStyle: UIBarButtonItem.Style?
        /// The raw value of the item's `UIBarButtonItem.AxisBehavior`.
        var originalAxisBehavior: Int?

        func restore() {
            if let originalStyle {
                item.style = originalStyle
            }
            #if compiler(>=6.4.2)
            if #available(iOS 27.1, *),
               let originalAxisBehavior,
               let axisBehavior = UIBarButtonItem.AxisBehavior(rawValue: originalAxisBehavior) {
                item.axisBehavior = axisBehavior
            }
            #endif
        }
    }

    /// The item whose menu holds `items`. The same items keep the same item,
    /// so setting them again leaves the bar as it is.
    private func overflowItem(for items: [UIBarButtonItem]) -> UIBarButtonItem {
        if let overflow, overflow.sources.elementsEqual(items, by: { $0 === $1 }) {
            return overflow.item
        }
        let item = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis"),
            menu: UIMenu(children: [Self.makeOverflowElement(for: items)])
        )
        overflow = (item, items)
        return item
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
                    .compactMap { item in
                        let element = item.menuRepresentation ?? makeMenuElement(for: item)
                        return item.isEnabled ? element : element.map(makeDisabledElement)
                    }
            )
        }
    }

    /// A menu element for an item without a menu representation of its own:
    /// its primary action, target-action, or selection as an action, its menu
    /// as a submenu, or both together.
    private static func makeMenuElement(for item: UIBarButtonItem) -> UIMenuElement? {
        let primaryAction = item.primaryAction
        let title = [item.title, primaryAction?.title, item.menu?.title, item.accessibilityLabel]
            .compactMap { $0 }
            .first { !$0.isEmpty } ?? ""
        let image = item.image ?? primaryAction?.image ?? item.menu?.image

        // With a menu, the selection follows the menu's own choice.
        let togglesSelection = item.changesSelectionAsPrimaryAction && item.menu == nil
        guard primaryAction != nil || item.action != nil || togglesSelection else {
            return item.menu.map { menu in
                UIMenu(
                    title: title,
                    image: image,
                    options: menu.options.subtracting(.displayInline),
                    children: menu.children
                )
            }
        }

        let action = UIAction(
            title: title,
            image: image,
            state: item.isSelected ? .on : .off
        ) { [weak item] _ in
            guard let item else {
                return
            }
            if togglesSelection {
                item.isSelected.toggle()
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
        guard let menu = item.menu else {
            return action
        }
        // The item's own action leads its menu's commands.
        return UIMenu(
            title: title,
            image: image,
            children: [
                action,
                UIMenu(options: menu.options.union(.displayInline), children: menu.children)
            ]
        )
    }

    /// The element as a disabled item's entry: it keeps its title and image
    /// and cannot be chosen or opened.
    private static func makeDisabledElement(_ element: UIMenuElement) -> UIMenuElement {
        if let action = (element as? UIAction)?.copy() as? UIAction {
            action.attributes.insert(.disabled)
            return action
        }
        return UIAction(
            title: element.title,
            image: element.image,
            attributes: .disabled
        ) { _ in }
    }
}

/// Counts the installations that rely on a toolbar FloatingAccessoryKit made
/// visible, so the toolbar hides again only when the last one leaves.
@MainActor
private final class RevealedToolbarUsers {
    private static var associationKey: UInt8 = 0
    private var count = 1

    /// Returns whether the navigation controller's toolbar is one that
    /// FloatingAccessoryKit made visible. A toolbar the app shows itself is
    /// left alone.
    static func add(
        to navigationController: UINavigationController,
        animated: Bool
    ) -> Bool {
        if let users = users(of: navigationController) {
            users.count += 1
            return true
        }
        guard navigationController.isToolbarHidden else {
            return false
        }
        navigationController.setToolbarHidden(false, animated: animated)
        objc_setAssociatedObject(
            navigationController,
            &associationKey,
            RevealedToolbarUsers(),
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        return true
    }

    static func remove(
        from navigationController: UINavigationController,
        animated: Bool
    ) {
        guard let users = users(of: navigationController) else {
            return
        }
        users.count -= 1
        guard users.count == 0 else {
            return
        }
        objc_setAssociatedObject(
            navigationController,
            &associationKey,
            nil,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        navigationController.setToolbarHidden(true, animated: animated)
    }

    private static func users(
        of navigationController: UINavigationController
    ) -> RevealedToolbarUsers? {
        objc_getAssociatedObject(navigationController, &associationKey) as? RevealedToolbarUsers
    }
}
