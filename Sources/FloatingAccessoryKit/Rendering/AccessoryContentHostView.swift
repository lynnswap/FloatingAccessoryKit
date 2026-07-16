import UIKit

@MainActor
final class AccessoryContentHostView: UIView {
    private(set) var contentView: UIView?
    private var contentConstraints: [NSLayoutConstraint] = []
    private var originalTranslatesAutoresizingMaskIntoConstraints: Bool?
    private let preferredSizeDidChange: @MainActor () -> Void
    private var lastObservedFittingSize: CGSize?

    init(
        contentView: UIView,
        preferredSizeDidChange: @escaping @MainActor () -> Void
    ) {
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
        let owner: UIView = self

        // `isolated deinit` requires iOS 18.4. This package supports iOS 18.0,
        // so assert the type's MainActor confinement for the synchronous
        // UIKit cleanup backstop.
        MainActor.assumeIsolated {
            NSLayoutConstraint.deactivate(contentConstraints)
            if contentView?.superview === owner,
               let contentView,
               let originalTranslatesAutoresizingMaskIntoConstraints {
                contentView.translatesAutoresizingMaskIntoConstraints =
                    originalTranslatesAutoresizingMaskIntoConstraints
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        guard let contentView else {
            return
        }

        let fittingSize = measuredFittingSize(for: contentView)
        guard lastObservedFittingSize?.isNearlyEqual(to: fittingSize) != true else {
            return
        }

        lastObservedFittingSize = fittingSize
        preferredSizeDidChange()
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
        if isStillOwned,
           let originalTranslatesAutoresizingMaskIntoConstraints {
            contentView.translatesAutoresizingMaskIntoConstraints = originalTranslatesAutoresizingMaskIntoConstraints
        }

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

        let trailing = contentView.trailingAnchor.constraint(equalTo: trailingAnchor)
        let bottom = contentView.bottomAnchor.constraint(equalTo: bottomAnchor)
        trailing.priority = .init(999)
        bottom.priority = .init(999)
        contentConstraints = [
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            trailing,
            bottom
        ]
        NSLayoutConstraint.activate(contentConstraints)
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
