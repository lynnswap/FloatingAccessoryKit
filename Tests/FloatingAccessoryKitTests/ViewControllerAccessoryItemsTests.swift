import Testing
import UIKit
@testable import FloatingAccessoryKit

@MainActor
@Suite
struct ViewControllerAccessoryItemsTests {
    @Test func itemsFollowTheHorizontalSizeClassAndLeaveTheBarsAsTheyWere() {
        let content = UIViewController()
        let navigationController = UINavigationController(rootViewController: content)
        navigationController.loadViewIfNeeded()
        let primaryItem = UIBarButtonItem(systemItem: .add)
        let otherItem = UIBarButtonItem(systemItem: .action)

        content.traitOverrides.horizontalSizeClass = .compact
        content.setFloatingAccessoryItems([otherItem, primaryItem], primaryItem: primaryItem)
        #expect(
            content.toolbarItems?.suffix(2).elementsEqual([otherItem, primaryItem]) { $0 === $1 } == true
        )
        #expect(!navigationController.isToolbarHidden)
        #expect(content.floatingAccessoryItems == [otherItem, primaryItem])

        content.traitOverrides.horizontalSizeClass = .regular
        content.updateTraitsIfNeeded()
        #expect(content.toolbarItems == nil)
        #expect(navigationController.isToolbarHidden)
        #expect(
            content.navigationItem.trailingItemGroups.last?.barButtonItems
                .elementsEqual([primaryItem]) { $0 === $1 } == true
        )
        #expect(content.navigationItem.additionalOverflowItems != nil)

        content.setFloatingAccessoryItems([])
        #expect(content.navigationItem.trailingItemGroups.isEmpty)
        #expect(content.navigationItem.additionalOverflowItems == nil)
        #expect(content.floatingAccessoryItems.isEmpty)
    }

    @Test func toolbarStaysVisibleWhileAnotherViewControllerStillHasItems() {
        let first = UIViewController()
        let second = UIViewController()
        let navigationController = UINavigationController(rootViewController: first)
        navigationController.loadViewIfNeeded()
        first.traitOverrides.horizontalSizeClass = .compact
        second.traitOverrides.horizontalSizeClass = .compact

        first.setFloatingAccessoryItems([UIBarButtonItem(systemItem: .add)])
        navigationController.pushViewController(second, animated: false)
        second.setFloatingAccessoryItems([UIBarButtonItem(systemItem: .action)])

        first.setFloatingAccessoryItems([])
        #expect(!navigationController.isToolbarHidden)

        second.setFloatingAccessoryItems([])
        #expect(navigationController.isToolbarHidden)
    }
}
