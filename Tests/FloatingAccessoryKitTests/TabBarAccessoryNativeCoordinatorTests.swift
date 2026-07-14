import Testing
import UIKit
@testable import FloatingAccessoryKit

@MainActor
@Suite
struct TabBarAccessoryNativeCoordinatorTests {
    @Test func setHiddenWithoutContentIsNoOp() {
        guard #available(iOS 26.0, *) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let coordinator = TabBarAccessoryCoordinator()

        coordinator.setHidden(true, animated: false, in: tabBarController)

        #expect(coordinator.isHidden == false)
        #expect(tabBarController.bottomAccessory == nil)
    }

    @Test func setAccessoryViewInstallsBottomAccessory() {
        guard #available(iOS 26.0, *) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let coordinator = TabBarAccessoryCoordinator()
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )

        #expect(tabBarController.bottomAccessory != nil)
        #expect(coordinator.isHidden == false)
    }

    @Test func setAccessoryViewUsesFiniteInitialSizeForContentWithoutIntrinsicSize() throws {
        guard #available(iOS 26.0, *) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let coordinator = TabBarAccessoryCoordinator()
        let contentView = NoIntrinsicSizeView()

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()
        coordinator.update(in: tabBarController)

        let width = try #require(contentView.constraints.first { $0.firstAttribute == .width })
        let height = try #require(contentView.constraints.first { $0.firstAttribute == .height })

        #expect(width.constant.isFinite)
        #expect(width.constant > 0)
        #expect(height.constant.isFinite)
        #expect(height.constant > 0)
    }

    @Test func sameViewRecomputesProposedHeightFittingWidth() throws {
        guard #available(iOS 26.0, *) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let coordinator = TabBarAccessoryCoordinator()
        let contentView = MutableSizeView(size: CGSize(width: 44, height: 32))

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()
        coordinator.update(in: tabBarController)

        let container = try #require(contentView.superview)
        let bottomAccessory = try #require(tabBarController.bottomAccessory)
        let nativeHeight = TabBarAccessoryContainerSizing.availableHeight(for: container)
        let initialSize = try constrainedSize(of: contentView)
        #expect(abs(initialSize.height - nativeHeight) <= 0.5)
        #expect(initialSize.width >= nativeHeight)

        contentView.size = CGSize(width: 92, height: 32)
        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()
        coordinator.update(in: tabBarController)

        #expect(tabBarController.bottomAccessory === bottomAccessory)
        #expect(contentView.superview === container)
        let updatedSize = try constrainedSize(of: contentView)
        let managedWidth = try managedConstraint(
            of: contentView,
            identifier: "FloatingAccessoryKit.contentWidth"
        )
        let managedHeight = try managedConstraint(
            of: contentView,
            identifier: "FloatingAccessoryKit.contentHeight"
        )
        NSLayoutConstraint.deactivate([managedWidth, managedHeight])
        let proposedHeightFittingSize = contentView.systemLayoutSizeFitting(
            CGSize(width: UIView.layoutFittingCompressedSize.width, height: nativeHeight),
            withHorizontalFittingPriority: .fittingSizeLevel,
            verticalFittingPriority: .required
        )
        NSLayoutConstraint.activate([managedWidth, managedHeight])
        let expectedWidth = max(
            nativeHeight,
            nativeHeight * proposedHeightFittingSize.width / proposedHeightFittingSize.height
        )
        #expect(abs(updatedSize.height - nativeHeight) <= 0.5)
        #expect(abs(updatedSize.width - expectedWidth) <= 0.5)
    }

    @Test func systemMenuButtonsFitNativeHeightAsSameStackGrows() throws {
        guard #available(iOS 26.0, *) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let coordinator = TabBarAccessoryCoordinator()
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false
        var installedAccessory: UITabAccessory?
        var installedContainer: UIView?
        var previousWidth: CGFloat?

        for buttonCount in 1...3 {
            let button = makeSystemMenuButton()
            #expect(button.constraints.allSatisfy { constraint in
                constraint.firstAttribute != .width && constraint.firstAttribute != .height
            })
            stackView.addArrangedSubview(button)

            coordinator.setAccessoryView(
                stackView,
                position: .trailing,
                animated: false,
                in: tabBarController
            )
            tabBarController.view.layoutIfNeeded()
            coordinator.update(in: tabBarController)

            let container = try #require(stackView.superview)
            let bottomAccessory = try #require(tabBarController.bottomAccessory)
            if let installedAccessory {
                #expect(bottomAccessory === installedAccessory)
                #expect(container === installedContainer)
            } else {
                installedAccessory = bottomAccessory
                installedContainer = container
            }
            let size = try constrainedSize(of: stackView)
            let nativeHeight = TabBarAccessoryContainerSizing.availableHeight(for: container)
            let referenceStack = makeSystemButtonStack(buttonCount: buttonCount)
            let fittingSize = referenceStack.systemLayoutSizeFitting(
                CGSize(width: UIView.layoutFittingCompressedSize.width, height: nativeHeight),
                withHorizontalFittingPriority: .fittingSizeLevel,
                verticalFittingPriority: .required
            )
            let expectedWidth = buttonCount == 1 ? nativeHeight : fittingSize.width

            #expect(abs(size.height - nativeHeight) <= 0.5)
            #expect(abs(size.width - expectedWidth) <= 0.5)
            #expect(abs(container.bounds.width - size.width) <= 1)
            if buttonCount == 1 {
                #expect(abs(size.width - size.height) <= 0.5)
                #expect(abs(container.bounds.width - container.bounds.height) <= 0.5)
            }
            if let previousWidth {
                #expect(size.width > previousWidth)
            }
            previousWidth = size.width
        }
    }

    @Test func nearSquareNaturalSizeSnapsNativeContainerToSquare() throws {
        guard #available(iOS 26.0, *) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let coordinator = TabBarAccessoryCoordinator()
        let contentView = MutableSizeView(size: CGSize(width: 48.01, height: 48))

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()
        coordinator.update(in: tabBarController)

        let container = try #require(contentView.superview)
        let size = try constrainedSize(of: contentView)
        #expect(abs(size.width - size.height) <= 0.5)
        #expect(abs(container.bounds.width - container.bounds.height) <= 0.5)
    }

    @Test func unchangedWidthLifecycleUsesCachedMeasurementUntilSameViewResubmission() throws {
        guard #available(iOS 26.0, *) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let accessoryController = TabBarAccessoryController(
            tabBarController: tabBarController
        )
        let contentView = CountingSizeView(size: CGSize(width: 44, height: 44))

        accessoryController.setContent(contentView)
        tabBarController.view.setNeedsLayout()
        tabBarController.view.layoutIfNeeded()

        let container = try #require(contentView.superview)
        let bottomAccessory = try #require(tabBarController.bottomAccessory)
        let widthConstraint = try managedConstraint(
            of: contentView,
            identifier: "FloatingAccessoryKit.contentWidth"
        )
        let heightConstraint = try managedConstraint(
            of: contentView,
            identifier: "FloatingAccessoryKit.contentHeight"
        )
        let nativeHeight = TabBarAccessoryContainerSizing.availableHeight(for: container)
        let initialSize = CGSize(width: nativeHeight, height: nativeHeight)
        let initialMeasurementCount = contentView.measurementCount
        #expect(initialMeasurementCount > 0)
        #expect(try constrainedSize(of: contentView) == initialSize)

        for _ in 0..<3 {
            tabBarController.view.setNeedsLayout()
            tabBarController.view.layoutIfNeeded()
        }
        #expect(contentView.measurementCount == initialMeasurementCount)

        contentView.size = CGSize(width: 92, height: 44)
        tabBarController.view.setNeedsLayout()
        tabBarController.view.layoutIfNeeded()

        #expect(contentView.measurementCount == initialMeasurementCount)
        #expect(try constrainedSize(of: contentView) == initialSize)

        accessoryController.setContent(contentView)
        tabBarController.view.setNeedsLayout()
        tabBarController.view.layoutIfNeeded()

        #expect(tabBarController.bottomAccessory === bottomAccessory)
        #expect(contentView.superview === container)
        #expect(contentView.measurementCount > initialMeasurementCount)
        #expect(widthConstraint.isActive)
        #expect(heightConstraint.isActive)
        #expect(
            try managedConstraint(
                of: contentView,
                identifier: "FloatingAccessoryKit.contentWidth"
            ) === widthConstraint
        )
        #expect(
            try managedConstraint(
                of: contentView,
                identifier: "FloatingAccessoryKit.contentHeight"
            ) === heightConstraint
        )
        let updatedSize = try constrainedSize(of: contentView)
        #expect(abs(updatedSize.height - nativeHeight) <= 0.5)
        #expect(abs(updatedSize.width - nativeHeight * 92 / 44) <= 0.5)
    }

    @Test func availableHeightChangeRemeasuresSameView() throws {
        guard #available(iOS 26.0, *) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let coordinator = TabBarAccessoryCoordinator()
        let contentView = CountingSizeView(size: CGSize(width: 44, height: 44))

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()
        coordinator.update(in: tabBarController)

        let container = try #require(contentView.superview)
        let bottomAccessory = try #require(tabBarController.bottomAccessory)
        let initialMeasurementCount = contentView.measurementCount
        TabBarAccessoryContainerSizing.unregister(container: container)

        container.bounds.size.height = 32
        coordinator.update(in: tabBarController)

        #expect(contentView.measurementCount > initialMeasurementCount)
        #expect(try constrainedSize(of: contentView) == CGSize(width: 32, height: 32))
        let compactMeasurementCount = contentView.measurementCount

        container.bounds.size.height = 64
        coordinator.update(in: tabBarController)

        #expect(tabBarController.bottomAccessory === bottomAccessory)
        #expect(contentView.superview === container)
        #expect(contentView.measurementCount > compactMeasurementCount)
        #expect(try constrainedSize(of: contentView) == CGSize(width: 64, height: 64))
    }

    @Test func sameViewPositionChangesKeepNativeIdentityAndReplaceAlignment() throws {
        guard #available(iOS 26.0, *) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let coordinator = TabBarAccessoryCoordinator()
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()
        coordinator.update(in: tabBarController)

        let container = try #require(contentView.superview)
        let bottomAccessory = try #require(tabBarController.bottomAccessory)
        let trailing = try activeAlignmentConstraint(for: contentView, attribute: .trailing)

        coordinator.setAccessoryView(
            contentView,
            position: .center,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()
        coordinator.update(in: tabBarController)

        let center = try activeAlignmentConstraint(for: contentView, attribute: .centerX)
        #expect(tabBarController.bottomAccessory === bottomAccessory)
        #expect(contentView.superview === container)
        #expect(!trailing.isActive)
        #expect(center.isActive)

        coordinator.setAccessoryView(
            contentView,
            position: .leading,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()
        coordinator.update(in: tabBarController)

        let leading = try activeAlignmentConstraint(for: contentView, attribute: .leading)
        #expect(tabBarController.bottomAccessory === bottomAccessory)
        #expect(contentView.superview === container)
        #expect(!center.isActive)
        #expect(leading.isActive)
    }

    @Test func aspectFittingWidthTracksNativeMaximumWidth() throws {
        guard #available(iOS 26.0, *) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let coordinator = TabBarAccessoryCoordinator()
        let contentView = WidthDependentSizeView(
            naturalSize: CGSize(width: 500, height: 20)
        )

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()
        coordinator.update(in: tabBarController)

        let container = try #require(contentView.superview)
        let maximumWidth = TabBarAccessoryContainerSizing.availableWidth(for: container)
        let maximumHeight = TabBarAccessoryContainerSizing.availableHeight(for: container)
        #expect(
            try constrainedSize(of: contentView)
                == CGSize(width: maximumWidth, height: maximumHeight)
        )

        tabBarController.view.frame.size.width = 200
        tabBarController.view.setNeedsLayout()
        tabBarController.view.layoutIfNeeded()
        coordinator.update(in: tabBarController)

        let shrunkenContainer = try #require(contentView.superview)
        let shrunkenMaximumWidth = TabBarAccessoryContainerSizing.availableWidth(
            for: shrunkenContainer
        )
        let shrunkenMaximumHeight = TabBarAccessoryContainerSizing.availableHeight(
            for: shrunkenContainer
        )
        #expect(shrunkenMaximumWidth < maximumWidth)
        #expect(
            try constrainedSize(of: contentView)
                == CGSize(width: shrunkenMaximumWidth, height: shrunkenMaximumHeight)
        )

        tabBarController.view.frame.size.width = 844
        tabBarController.view.setNeedsLayout()
        tabBarController.view.layoutIfNeeded()
        coordinator.update(in: tabBarController)

        let grownContainer = try #require(contentView.superview)
        let grownMaximumWidth = TabBarAccessoryContainerSizing.availableWidth(for: grownContainer)
        let grownMaximumHeight = TabBarAccessoryContainerSizing.availableHeight(for: grownContainer)
        #expect(grownMaximumWidth > shrunkenMaximumWidth)
        #expect(
            try constrainedSize(of: contentView)
                == CGSize(width: grownMaximumWidth, height: grownMaximumHeight)
        )
    }

    @Test func multilineLabelIsBoundedByNativeAccessorySize() throws {
        guard #available(iOS 26.0, *) else {
            return
        }

        let text = Array(repeating: "Floating accessory content", count: 20).joined(separator: " ")
        let makeLabel = { (text: String) in
            let label = UILabel()
            label.font = .systemFont(ofSize: 17)
            label.numberOfLines = 0
            label.text = text
            return label
        }
        let tabBarController = makeTestTabBarController()
        let coordinator = TabBarAccessoryCoordinator()
        let contentView = makeLabel(text)

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()
        coordinator.update(in: tabBarController)

        let container = try #require(contentView.superview)

        let maximumWidth = TabBarAccessoryContainerSizing.availableWidth(for: container)
        let maximumHeight = TabBarAccessoryContainerSizing.availableHeight(for: container)
        let constrainedSize = try constrainedSize(of: contentView)

        #expect(abs(constrainedSize.width - maximumWidth) <= 0.5)
        #expect(abs(constrainedSize.height - maximumHeight) <= 0.5)
    }

    @Test func overlaySameViewResubmissionKeepsHostAndUpdatesSize() throws {
        guard #unavailable(iOS 26.0) else {
            return
        }

        let tabBarController = makeEmptyTestTabBarController()
        _ = addTestTabBarButton(height: 64, to: tabBarController)
        let accessoryController = TabBarAccessoryController(
            tabBarController: tabBarController
        )
        let contentView = MutableSizeView(size: CGSize(width: 44, height: 44))

        accessoryController.setContent(contentView)
        tabBarController.view.layoutIfNeeded()

        let hostView = try #require(contentView.superview)
        #expect(hostView.bounds.size == CGSize(width: 64, height: 64))

        contentView.size = CGSize(width: 120, height: 80)
        accessoryController.setContent(contentView)
        tabBarController.view.layoutIfNeeded()

        #expect(contentView.superview === hostView)
        #expect(hostView.bounds.size == CGSize(width: 96, height: 64))
    }

    @Test func oversizedSquarePreferredSizeUsesNativeSquare() throws {
        guard #available(iOS 26.0, *) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let coordinator = TabBarAccessoryCoordinator()
        let contentView = MutableSizeView(size: CGSize(width: 44, height: 44))

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()
        coordinator.update(in: tabBarController)

        let container = try #require(contentView.superview)
        let maximumWidth = TabBarAccessoryContainerSizing.availableWidth(for: container)
        let maximumHeight = TabBarAccessoryContainerSizing.availableHeight(for: container)
        #expect(maximumWidth.isFinite && maximumWidth > 0)
        #expect(maximumHeight.isFinite && maximumHeight > 0)

        contentView.size = CGSize(width: 1_000, height: 1_000)
        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()
        coordinator.update(in: tabBarController)

        let constrainedSize = try constrainedSize(of: contentView)
        #expect(abs(constrainedSize.width - maximumHeight) <= 0.5)
        #expect(abs(constrainedSize.height - maximumHeight) <= 0.5)
    }

    @Test func setHiddenRemovesAndRestoresBottomAccessory() {
        guard #available(iOS 26.0, *) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let coordinator = TabBarAccessoryCoordinator()
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        let bottomAccessory = tabBarController.bottomAccessory

        coordinator.setHidden(true, animated: false, in: tabBarController)
        #expect(coordinator.isHidden == true)
        #expect(tabBarController.bottomAccessory == nil)

        coordinator.setHidden(false, animated: false, in: tabBarController)
        #expect(coordinator.isHidden == false)
        #expect(tabBarController.bottomAccessory === bottomAccessory)
    }

    @Test func setAccessoryViewNilClearsBottomAccessoryAndHiddenState() {
        guard #available(iOS 26.0, *) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let coordinator = TabBarAccessoryCoordinator()
        let contentView = FixedSizeView(size: CGSize(width: 44, height: 44))

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        coordinator.setHidden(true, animated: false, in: tabBarController)
        coordinator.setAccessoryView(nil, position: .trailing, animated: false, in: tabBarController)

        #expect(tabBarController.bottomAccessory == nil)
        #expect(coordinator.isHidden == false)
    }

    @Test func replacingContentViewReplacesBottomAccessory() {
        guard #available(iOS 26.0, *) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let coordinator = TabBarAccessoryCoordinator()
        let firstView = FixedSizeView(size: CGSize(width: 44, height: 44))
        let secondView = FixedSizeView(size: CGSize(width: 88, height: 44))

        coordinator.setAccessoryView(
            firstView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        let firstAccessory = tabBarController.bottomAccessory

        coordinator.setAccessoryView(
            secondView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )

        #expect(tabBarController.bottomAccessory != nil)
        #expect(tabBarController.bottomAccessory !== firstAccessory)
        #expect(coordinator.isHidden == false)
    }

    private func makeSystemMenuButton() -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "plus")
        configuration.buttonSize = .large
        configuration.cornerStyle = .capsule

        let button = UIButton(configuration: configuration)
        button.menu = UIMenu(children: [
            UIAction(title: "Action") { _ in }
        ])
        button.showsMenuAsPrimaryAction = true
        return button
    }

    private func makeSystemButtonStack(buttonCount: Int) -> UIStackView {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 4
        for _ in 0..<buttonCount {
            stackView.addArrangedSubview(makeSystemMenuButton())
        }
        return stackView
    }

    private func constrainedSize(of view: UIView) throws -> CGSize {
        let width = try managedConstraint(
            of: view,
            identifier: "FloatingAccessoryKit.contentWidth"
        )
        let height = try managedConstraint(
            of: view,
            identifier: "FloatingAccessoryKit.contentHeight"
        )
        return CGSize(width: width.constant, height: height.constant)
    }

    private func managedConstraint(
        of view: UIView,
        identifier: String
    ) throws -> NSLayoutConstraint {
        try #require(view.constraints.first { constraint in
            constraint.identifier == identifier && constraint.isActive
        })
    }

    private func activeAlignmentConstraint(
        for view: UIView,
        attribute: NSLayoutConstraint.Attribute
    ) throws -> NSLayoutConstraint {
        let constraints = [view, view.superview]
            .compactMap { $0 }
            .flatMap(\.constraints)
        return try #require(constraints.first { constraint in
            constraint.isActive
                && constraint.firstItem === view
                && constraint.firstAttribute == attribute
        })
    }
}

private final class WidthDependentSizeView: UIView {
    let naturalSize: CGSize

    init(naturalSize: CGSize) {
        self.naturalSize = naturalSize

        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        naturalSize
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        naturalSize
    }

    override func systemLayoutSizeFitting(
        _ targetSize: CGSize,
        withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
        verticalFittingPriority: UILayoutPriority
    ) -> CGSize {
        guard horizontalFittingPriority == .required,
              targetSize.width.isFinite,
              targetSize.width > 0,
              targetSize.width < naturalSize.width else {
            return naturalSize
        }

        let lineCount = ceil(naturalSize.width / targetSize.width)
        return CGSize(
            width: targetSize.width,
            height: naturalSize.height * lineCount
        )
    }
}

private final class CountingSizeView: UIView {
    var size: CGSize {
        didSet {
            invalidateIntrinsicContentSize()
        }
    }
    private(set) var measurementCount = 0

    init(size: CGSize) {
        self.size = size

        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        size
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        self.size
    }

    override func systemLayoutSizeFitting(
        _ targetSize: CGSize,
        withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
        verticalFittingPriority: UILayoutPriority
    ) -> CGSize {
        measurementCount += 1
        return size
    }
}
