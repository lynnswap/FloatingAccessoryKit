import UIKit

/// Lays out the views for a list of bar button items along the accessory's
/// axis and animates items in and out.
@MainActor
final class AccessoryItemsView: UIView {
    struct Transition {
        /// Whether an item arrives, leaves, or moves.
        let changesVisibleItems: Bool
        /// Layout changes to run inside the accessory's animation.
        let updates: @MainActor () -> Void
        /// Removes the views that left once the animation has finished.
        let completion: @MainActor () -> Void
    }

    private final class Entry {
        let item: UIBarButtonItem
        /// The item's custom view when the entry was made. An item whose
        /// custom view has changed since gets a new entry.
        let customView: UIView?
        let view: UIView

        init(item: UIBarButtonItem, view: UIView) {
            self.item = item
            customView = item.customView
            self.view = view
        }
    }

    /// Called when an item's `isHidden` changes.
    var visibleItemsDidChange: (@MainActor () -> Void)?

    private(set) var items: [UIBarButtonItem] = []
    private let stackView = UIStackView()
    private var entries: [Entry] = []
    private var leavingViews: [UIView] = []
    private var hiddenObservations: [NSKeyValueObservation] = []

    var hasVisibleItems: Bool {
        !entries.isEmpty
    }

    init() {
        super.init(frame: .zero)

        stackView.axis = traitCollection.floatingAccessoryAxis
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        registerForTraitChanges([FloatingAccessoryAxisTrait.self]) {
            (view: AccessoryItemsView, _: UITraitCollection) in
            view.stackView.axis = view.traitCollection.floatingAccessoryAxis
            view.invalidateIntrinsicContentSize()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    isolated deinit {
        // Custom views outlive the items view; give them back in the layout
        // mode their owners left them in.
        for view in entries.map(\.view) + leavingViews {
            (view as? AccessoryItemSlotView)?.releaseContentView()
        }
    }

    /// Replaces the items without animation.
    func setItems(_ items: [UIBarButtonItem]) {
        let transition = prepareTransition(to: items)
        UIView.performWithoutAnimation {
            transition.updates()
        }
        transition.completion()
    }

    /// Installs views for arriving items at their starting position and
    /// returns the changes that move every item to its final layout.
    func prepareTransition(to items: [UIBarButtonItem]) -> Transition {
        removeLeavingViews()
        observeHidden(of: items)
        self.items = items

        var newEntries: [Entry] = []
        var arriving: [Entry] = []
        for item in items where !item.isHidden {
            if let entry = entries.first(where: {
                $0.item === item && $0.customView === item.customView
            }) {
                newEntries.append(entry)
            } else {
                let entry = Entry(item: item, view: makeView(for: item))
                newEntries.append(entry)
                arriving.append(entry)
            }
        }
        let leaving = entries.filter { entry in
            !newEntries.contains { $0 === entry }
        }

        for (index, entry) in newEntries.enumerated()
        where arriving.contains(where: { $0 === entry }) {
            let nextStayingView = newEntries[(index + 1)...]
                .first { candidate in
                    !arriving.contains { $0 === candidate }
                }?
                .view
            install(entry.view, before: nextStayingView)
        }

        let changesVisibleItems = !entries.elementsEqual(newEntries) { $0 === $1 }
        entries = newEntries
        leavingViews = leaving.map(\.view)
        let orderedViews = newEntries.map(\.view)

        return Transition(
            changesVisibleItems: changesVisibleItems,
            updates: { [stackView] in
                for view in leaving.map(\.view) {
                    view.isHidden = true
                    view.alpha = 0
                }
                for view in arriving.map(\.view) {
                    view.isHidden = false
                    view.alpha = 1
                }
                let currentOrder = stackView.arrangedSubviews.filter { view in
                    orderedViews.contains { $0 === view }
                }
                if !currentOrder.elementsEqual(orderedViews, by: { $0 === $1 }) {
                    for (index, view) in orderedViews.enumerated() {
                        stackView.insertArrangedSubview(view, at: index)
                    }
                }
                self.invalidateIntrinsicContentSize()
                stackView.layoutIfNeeded()
            },
            completion: { [weak self] in
                self?.removeLeavingViews(leaving.map(\.view))
            }
        )
    }

    private func makeView(for item: UIBarButtonItem) -> UIView {
        AccessoryItemSlotView(
            contentView: item.customView ?? AccessoryItemButton(item: item)
        )
    }

    /// Adds an arriving view collapsed at the edge it grows from, so the
    /// animation expands it in place instead of from the view's origin.
    private func install(_ view: UIView, before nextStayingView: UIView?) {
        let index = nextStayingView
            .flatMap { stackView.arrangedSubviews.firstIndex(of: $0) }
            ?? stackView.arrangedSubviews.count
        let bounds = stackView.bounds
        let isRightToLeft = effectiveUserInterfaceLayoutDirection == .rightToLeft
        let startFrame: CGRect
        if stackView.axis == .vertical {
            startFrame = CGRect(
                x: 0,
                y: nextStayingView?.frame.minY ?? bounds.maxY,
                width: bounds.width,
                height: 0
            )
        } else {
            let x = isRightToLeft
                ? nextStayingView?.frame.maxX ?? bounds.minX
                : nextStayingView?.frame.minX ?? bounds.maxX
            startFrame = CGRect(x: x, y: 0, width: 0, height: bounds.height)
        }

        UIView.performWithoutAnimation {
            view.isHidden = true
            view.alpha = 0
            stackView.insertArrangedSubview(view, at: index)
            view.frame = startFrame
        }
    }

    private func removeLeavingViews(_ views: [UIView]? = nil) {
        let removedViews = views ?? leavingViews
        for view in removedViews where !entries.contains(where: { $0.view === view }) {
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
            (view as? AccessoryItemSlotView)?.releaseContentView()
        }
        leavingViews.removeAll { view in
            removedViews.contains { $0 === view }
        }
    }

    private func observeHidden(of items: [UIBarButtonItem]) {
        hiddenObservations.forEach { $0.invalidate() }
        hiddenObservations = items.map { item in
            item.observe(\.isHidden) { [weak self] _, _ in
                MainActor.assumeIsolated {
                    self?.visibleItemsDidChange?()
                }
            }
        }
    }
}

/// Holds one item's view so the stack can collapse the slot while the item's
/// own size constraints, such as a square aspect, stay satisfied.
@MainActor
private final class AccessoryItemSlotView: UIView {
    private let contentView: UIView
    private let originalTranslatesAutoresizingMaskIntoConstraints: Bool
    private var frameSizeConstraints: [NSLayoutConstraint] = []
    private var isContentViewReleased = false

    init(contentView: UIView) {
        self.contentView = contentView
        originalTranslatesAutoresizingMaskIntoConstraints =
            contentView.translatesAutoresizingMaskIntoConstraints

        super.init(frame: .zero)

        clipsToBounds = true
        contentView.translatesAutoresizingMaskIntoConstraints = false
        frameSizeConstraints = Self.makeFrameSizeConstraints(for: contentView)
        addSubview(contentView)
        let trailing = contentView.trailingAnchor.constraint(equalTo: trailingAnchor)
        let bottom = contentView.bottomAnchor.constraint(equalTo: bottomAnchor)
        trailing.priority = .init(999)
        bottom.priority = .init(999)
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            trailing,
            bottom
        ] + frameSizeConstraints)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Gives the view back to its owner.
    ///
    /// The autoresizing mode is restored unless another view has taken the
    /// content view in the meantime. UIKit detaches an item's previous custom
    /// view when the item gets a new one, which leaves it without a superview.
    func releaseContentView() {
        NSLayoutConstraint.deactivate(frameSizeConstraints)
        frameSizeConstraints = []
        if contentView.superview === self {
            contentView.removeFromSuperview()
        }
        guard contentView.superview == nil, !isContentViewReleased else {
            return
        }
        isContentViewReleased = true
        contentView.translatesAutoresizingMaskIntoConstraints =
            originalTranslatesAutoresizingMaskIntoConstraints
    }

    /// Keeps the frame size of a view that Auto Layout cannot size.
    ///
    /// A custom view laid out by its frame has no intrinsic size or size
    /// constraints, so it measures zero once its autoresizing mask no longer
    /// becomes constraints. The constraints rank below content hugging, so an
    /// intrinsic size or a size constraint that the view gains later wins.
    private static func makeFrameSizeConstraints(
        for contentView: UIView
    ) -> [NSLayoutConstraint] {
        // The autoresizing constraints stay in a measurement until the view
        // updates its constraints.
        contentView.setNeedsUpdateConstraints()
        contentView.updateConstraintsIfNeeded()
        let fittingSize = contentView.systemLayoutSizeFitting(
            UIView.layoutFittingCompressedSize,
            withHorizontalFittingPriority: .fittingSizeLevel,
            verticalFittingPriority: .fittingSizeLevel
        )
        let frameSize = contentView.bounds.size
        var constraints: [NSLayoutConstraint] = []
        if fittingSize.width <= 0, frameSize.width > 0 {
            constraints.append(
                contentView.widthAnchor.constraint(equalToConstant: frameSize.width)
            )
        }
        if fittingSize.height <= 0, frameSize.height > 0 {
            constraints.append(
                contentView.heightAnchor.constraint(equalToConstant: frameSize.height)
            )
        }
        for constraint in constraints {
            constraint.priority = UILayoutPriority(UILayoutPriority.defaultLow.rawValue - 1)
        }
        return constraints
    }
}
