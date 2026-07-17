import UIKit

@MainActor
final class AccessoryContentHostView: UIView {
    private(set) var contentView: UIView?
    private var contentConstraints: [NSLayoutConstraint] = []
    private var originalTranslatesAutoresizingMaskIntoConstraints: Bool?
    private let preferredSizeDidChange: @MainActor (_ animated: Bool) -> Void
    private var lastObservedFittingSize: CGSize?
    private var contentSizeObservation: AccessoryContentSizeObservation?

    init(
        contentView: UIView,
        preferredSizeDidChange: @escaping @MainActor (_ animated: Bool) -> Void
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

        // `isolated deinit` requires iOS 18.4. This package supports iOS 18.0,
        // so assert the type's MainActor confinement for the synchronous
        // UIKit cleanup backstop.
        MainActor.assumeIsolated {
            self.contentSizeObservation?.invalidate()
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

    override func didMoveToWindow() {
        super.didMoveToWindow()

        if window == nil {
            stopObservingContentSize()
        } else {
            startObservingContentSizeIfNeeded()
        }
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

        stopObservingContentSize()
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
        contentConstraints = [
            contentView.centerXAnchor.constraint(equalTo: centerXAnchor),
            contentView.centerYAnchor.constraint(equalTo: centerYAnchor),
            width,
            height
        ]
        NSLayoutConstraint.activate(contentConstraints)
    }

    private func startObservingContentSizeIfNeeded() {
        guard contentSizeObservation == nil,
              contentView != nil else {
            return
        }

        // A constraint owned entirely by the consumer's subtree does not
        // invalidate ancestor layout. Observe at the run-loop idle boundary so
        // those changes are detected without waking the display while idle.
        contentSizeObservation = AccessoryContentSizeObservation { [weak self] in
            self?.observePreferredSizeIfNeeded()
        }
        observePreferredSizeIfNeeded()
    }

    private func stopObservingContentSize() {
        guard let contentSizeObservation else {
            return
        }

        contentSizeObservation.invalidate()
        self.contentSizeObservation = nil
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

private final class AccessoryContentSizeObservation {
    private let observer: CFRunLoopObserver

    init(onRunLoopTurn: @escaping @MainActor () -> Void) {
        let activities = CFRunLoopActivity.beforeWaiting.rawValue
            | CFRunLoopActivity.exit.rawValue
        observer = CFRunLoopObserverCreateWithHandler(
            kCFAllocatorDefault,
            activities,
            true,
            0
        ) { _, _ in
            MainActor.assumeIsolated {
                onRunLoopTurn()
            }
        }
        CFRunLoopAddObserver(
            CFRunLoopGetMain(),
            observer,
            .commonModes
        )
    }

    func invalidate() {
        CFRunLoopObserverInvalidate(observer)
    }

    deinit {
        invalidate()
    }
}

private extension CGSize {
    func isNearlyEqual(to other: CGSize) -> Bool {
        abs(width - other.width) <= 0.5
            && abs(height - other.height) <= 0.5
    }
}
