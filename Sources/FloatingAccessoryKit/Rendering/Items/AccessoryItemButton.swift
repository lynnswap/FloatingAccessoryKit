import UIKit

/// A button that mirrors one `UIBarButtonItem` inside a floating accessory.
@MainActor
final class AccessoryItemButton: UIButton {
    private weak var item: UIBarButtonItem?
    private var observations: [NSKeyValueObservation] = []
    private lazy var squareConstraint = widthAnchor.constraint(
        equalTo: heightAnchor
    )

    init(item: UIBarButtonItem) {
        self.item = item

        super.init(frame: .zero)

        configuration = .plain()
        addAction(
            UIAction { [weak self] _ in
                self?.performItemAction()
            },
            for: .primaryActionTriggered
        )
        applyItem()
        observations = [
            item.observe(\.image) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.applyItem() }
            },
            item.observe(\.title) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.applyItem() }
            },
            item.observe(\.isEnabled) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.applyItem() }
            },
            item.observe(\.menu) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.applyItem() }
            },
            item.observe(\.primaryAction) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.applyItem() }
            },
            item.observe(\.tintColor) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.applyItem() }
            }
        ]
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func applyItem() {
        guard let item else {
            return
        }

        let image = item.image ?? item.primaryAction?.image
        let title = item.title ?? (image == nil ? item.primaryAction?.title : nil)
        var configuration = self.configuration ?? .plain()
        configuration.image = image
        configuration.title = title
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
            scale: .medium
        )
        // Inside the accessory's glass, a plain button draws in the label
        // color whatever its tint color is, so the item's tint is spelled out.
        configuration.baseForegroundColor = item.tintColor
        self.configuration = configuration

        isEnabled = item.isEnabled
        // System bars draw an item without a tint in the label color.
        tintColor = item.tintColor ?? .label
        menu = item.menu
        showsMenuAsPrimaryAction = item.menu != nil
            && item.primaryAction == nil
            && item.action == nil
        preferredMenuElementOrder = item.preferredMenuElementOrder
        accessibilityLabel = item.accessibilityLabel
            ?? title
            ?? item.primaryAction?.title
        accessibilityIdentifier = item.accessibilityIdentifier

        // An image-only item stays square along either layout axis.
        squareConstraint.isActive = title == nil
        invalidateIntrinsicContentSize()
    }

    private func performItemAction() {
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
