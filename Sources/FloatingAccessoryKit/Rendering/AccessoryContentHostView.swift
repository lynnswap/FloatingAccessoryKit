import UIKit

@MainActor
final class AccessoryContentHostView: UIView {
    private(set) var contentView: UIView?
    private var contentConstraints: [NSLayoutConstraint] = []
    private var horizontalConstraint: NSLayoutConstraint?
    private var originalTranslatesAutoresizingMaskIntoConstraints: Bool?
    private var position: TabBarAccessoryController.Position
    private let preferredSizeDidChange: @MainActor (_ animated: Bool) -> Void
    private var lastObservedFittingSize: CGSize?

    init(
        contentView: UIView,
        position: TabBarAccessoryController.Position,
        preferredSizeDidChange: @escaping @MainActor (_ animated: Bool) -> Void
    ) {
        self.position = position
        self.preferredSizeDidChange = preferredSizeDidChange

        super.init(frame: .zero)

        backgroundColor = .clear
        attach(contentView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        let contentView = contentView
        let contentConstraints = contentConstraints
        let originalTranslatesAutoresizingMaskIntoConstraints =
            originalTranslatesAutoresizingMaskIntoConstraints

        // `isolated deinit` requires iOS 18.4. This package supports iOS 18.0,
        // so assert the type's MainActor confinement for the synchronous
        // UIKit cleanup backstop.
        MainActor.assumeIsolated {
            NSLayoutConstraint.deactivate(contentConstraints)
            Self.restoreConsumerAutoresizingIfUnchanged(
                contentView,
                originalValue: originalTranslatesAutoresizingMaskIntoConstraints
            )
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        observePreferredSizeIfNeeded()
    }

    func invalidatePreferredSize(animated: Bool) {
        guard let contentView else {
            return
        }

        lastObservedFittingSize = measuredFittingSize(for: contentView)
        preferredSizeDidChange(animated)
    }

    func updatePosition(_ position: TabBarAccessoryController.Position) {
        guard self.position != position,
              let contentView else {
            return
        }

        self.position = position
        if let horizontalConstraint {
            horizontalConstraint.isActive = false
            contentConstraints.removeAll { $0 === horizontalConstraint }
        }

        let horizontalConstraint = makeHorizontalConstraint(for: contentView)
        self.horizontalConstraint = horizontalConstraint
        contentConstraints.append(horizontalConstraint)
        horizontalConstraint.isActive = true
        setNeedsLayout()
    }

    @discardableResult
    func detachContent(keepingSnapshot: Bool) -> UIView? {
        guard let contentView else {
            return nil
        }

        let isStillOwned = contentView.superview === self
        let snapshot = keepingSnapshot && isStillOwned
            ? contentView.snapshotView(afterScreenUpdates: false)
            : nil
        if let snapshot {
            snapshot.frame = bounds
            snapshot.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        }

        NSLayoutConstraint.deactivate(contentConstraints)
        contentConstraints.removeAll()
        if isStillOwned {
            contentView.removeFromSuperview()
        }
        Self.restoreConsumerAutoresizingIfUnchanged(
            contentView,
            originalValue: originalTranslatesAutoresizingMaskIntoConstraints
        )

        self.contentView = nil
        self.originalTranslatesAutoresizingMaskIntoConstraints = nil
        lastObservedFittingSize = nil

        if let snapshot {
            addSubview(snapshot)
        }
        return contentView
    }

    private func attach(_ contentView: UIView) {
        precondition(self.contentView == nil)

        self.contentView = contentView
        originalTranslatesAutoresizingMaskIntoConstraints = contentView.translatesAutoresizingMaskIntoConstraints
        contentView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentView)

        let width = contentView.widthAnchor.constraint(equalTo: widthAnchor)
        let height = contentView.heightAnchor.constraint(equalTo: heightAnchor)
        width.priority = .init(999)
        height.priority = .init(999)
        let horizontalConstraint = makeHorizontalConstraint(for: contentView)
        self.horizontalConstraint = horizontalConstraint
        contentConstraints = [
            horizontalConstraint,
            contentView.centerYAnchor.constraint(equalTo: centerYAnchor),
            width,
            height
        ]
        NSLayoutConstraint.activate(contentConstraints)
    }

    private func makeHorizontalConstraint(
        for contentView: UIView
    ) -> NSLayoutConstraint {
        if position == .leading {
            return contentView.leadingAnchor.constraint(equalTo: leadingAnchor)
        }
        if position == .trailing {
            return contentView.trailingAnchor.constraint(equalTo: trailingAnchor)
        }
        return contentView.centerXAnchor.constraint(equalTo: centerXAnchor)
    }

    private func observePreferredSizeIfNeeded() {
        guard let contentView else {
            return
        }

        let fittingSize = measuredFittingSize(for: contentView)
        guard lastObservedFittingSize?.isNearlyEqual(to: fittingSize) != true else {
            return
        }

        let animated = lastObservedFittingSize != nil
        lastObservedFittingSize = fittingSize
        preferredSizeDidChange(animated)
    }

    private static func restoreConsumerAutoresizingIfUnchanged(
        _ contentView: UIView?,
        originalValue: Bool?
    ) {
        guard let contentView,
              let originalValue,
              contentView.translatesAutoresizingMaskIntoConstraints == false else {
            return
        }

        contentView.translatesAutoresizingMaskIntoConstraints = originalValue
    }

    private func measuredFittingSize(for contentView: UIView) -> CGSize {
        let fittingSize = contentView.systemLayoutSizeFitting(
            UIView.layoutFittingCompressedSize,
            withHorizontalFittingPriority: .fittingSizeLevel,
            verticalFittingPriority: .fittingSizeLevel
        )
        if fittingSize.width > 0,
           fittingSize.height > 0 {
            return fittingSize
        }

        let intrinsicSize = contentView.intrinsicContentSize
        if intrinsicSize.width > 0,
           intrinsicSize.height > 0 {
            return intrinsicSize
        }

        return contentView.bounds.size
    }
}

private extension CGSize {
    func isNearlyEqual(to other: CGSize) -> Bool {
        abs(width - other.width) <= 0.5
            && abs(height - other.height) <= 0.5
    }
}
