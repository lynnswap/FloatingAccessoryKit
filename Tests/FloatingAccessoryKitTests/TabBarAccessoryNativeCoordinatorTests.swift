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

    @Test func sameViewRecomputesIntrinsicSizeWithoutScalingToContainerHeight() throws {
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
        #expect(container.bounds.height != 32)
        #expect(try constrainedSize(of: contentView) == CGSize(width: 44, height: 32))

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
        #expect(try constrainedSize(of: contentView) == CGSize(width: 92, height: 32))
    }

    @Test func sameStackViewRecomputesFittingSizeAsArrangedSubviewsChange() throws {
        guard #available(iOS 26.0, *) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let coordinator = TabBarAccessoryCoordinator()
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 4
        var installedAccessory: UITabAccessory?
        var installedContainer: UIView?

        for expectedWidth in [CGFloat(44), 92, 140] {
            let item = UIView()
            item.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                item.widthAnchor.constraint(equalToConstant: 44),
                item.heightAnchor.constraint(equalToConstant: 44)
            ])
            stackView.addArrangedSubview(item)

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
            #expect(try constrainedSize(of: stackView) == CGSize(width: expectedWidth, height: 44))
        }
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
        let initialMeasurementCount = contentView.measurementCount
        #expect(initialMeasurementCount > 0)
        #expect(try constrainedSize(of: contentView) == CGSize(width: 44, height: 44))

        for _ in 0..<3 {
            tabBarController.view.setNeedsLayout()
            tabBarController.view.layoutIfNeeded()
        }
        #expect(contentView.measurementCount == initialMeasurementCount)

        contentView.size = CGSize(width: 92, height: 44)
        tabBarController.view.setNeedsLayout()
        tabBarController.view.layoutIfNeeded()

        #expect(contentView.measurementCount == initialMeasurementCount)
        #expect(try constrainedSize(of: contentView) == CGSize(width: 44, height: 44))

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
        #expect(try constrainedSize(of: contentView) == CGSize(width: 92, height: 44))
    }

    @Test func explicitContentSizeConstraintsRemainThePreferredSize() throws {
        guard #available(iOS 26.0, *) else {
            return
        }

        let tabBarController = makeTestTabBarController()
        let coordinator = TabBarAccessoryCoordinator()
        let contentView = MutableSizeView(size: CGSize(width: 44, height: 44))
        contentView.translatesAutoresizingMaskIntoConstraints = false
        let explicitWidth = contentView.widthAnchor.constraint(equalToConstant: 92)
        let explicitHeight = contentView.heightAnchor.constraint(equalToConstant: 32)
        NSLayoutConstraint.activate([explicitWidth, explicitHeight])

        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()
        coordinator.update(in: tabBarController)

        #expect(try constrainedSize(of: contentView) == CGSize(width: 92, height: 32))

        contentView.size = CGSize(width: 140, height: 44)
        coordinator.setAccessoryView(
            contentView,
            position: .trailing,
            animated: false,
            in: tabBarController
        )
        tabBarController.view.layoutIfNeeded()
        coordinator.update(in: tabBarController)

        #expect(explicitWidth.isActive)
        #expect(explicitHeight.isActive)
        #expect(try constrainedSize(of: contentView) == CGSize(width: 92, height: 32))
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

    @Test func widthDependentContentRefitsHeightAtNativeMaximumWidth() throws {
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
        let expectedHeight = min(
            ceil(contentView.naturalSize.width / maximumWidth) * contentView.naturalSize.height,
            maximumHeight
        )
        #expect(
            try constrainedSize(of: contentView)
                == CGSize(width: maximumWidth, height: expectedHeight)
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
        let shrunkenExpectedHeight = min(
            ceil(contentView.naturalSize.width / shrunkenMaximumWidth)
                * contentView.naturalSize.height,
            shrunkenMaximumHeight
        )
        #expect(shrunkenMaximumWidth < maximumWidth)
        #expect(
            try constrainedSize(of: contentView)
                == CGSize(width: shrunkenMaximumWidth, height: shrunkenExpectedHeight)
        )

        tabBarController.view.frame.size.width = 844
        tabBarController.view.setNeedsLayout()
        tabBarController.view.layoutIfNeeded()
        coordinator.update(in: tabBarController)

        let grownContainer = try #require(contentView.superview)
        let grownMaximumWidth = TabBarAccessoryContainerSizing.availableWidth(for: grownContainer)
        #expect(grownMaximumWidth > contentView.naturalSize.width)
        #expect(try constrainedSize(of: contentView) == contentView.naturalSize)
    }

    @Test func multilineLabelRefitsHeightAtNativeMaximumWidth() throws {
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
        let naturalWidth = makeLabel(text).intrinsicContentSize.width
        let expectedFittingSize = makeLabel(text).systemLayoutSizeFitting(
            CGSize(width: maximumWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        let expectedHeight = min(expectedFittingSize.height, maximumHeight)
        let constrainedSize = try constrainedSize(of: contentView)

        #expect(naturalWidth > maximumWidth)
        #expect(expectedHeight > contentView.font.lineHeight)
        #expect(abs(constrainedSize.width - maximumWidth) <= 0.5)
        #expect(abs(constrainedSize.height - expectedHeight) <= 0.5)
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

    @Test func preferredSizeIsCappedToNativeContainerBounds() throws {
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
        #expect(abs(constrainedSize.width - maximumWidth) <= 0.5)
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
