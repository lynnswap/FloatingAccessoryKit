import UIKit

@MainActor
final class TabBarAccessoryLayoutObservationView: UIView {
    private let onLayout: @MainActor () -> Void
    private var isObservingChanges = false
    private var lastObservedLayout: ObservedLayout?

    init(onLayout: @escaping @MainActor () -> Void) {
        self.onLayout = onLayout

        super.init(frame: .zero)

        backgroundColor = .clear
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func startObservingChanges() {
        isObservingChanges = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        notifyIfLayoutChanged()
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        notifyIfLayoutChanged()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        lastObservedLayout = nil
        notifyIfLayoutChanged()
    }

    private func notifyIfLayoutChanged() {
        let observedLayout = ObservedLayout(
            bounds: bounds,
            safeAreaInsets: safeAreaInsets,
            layoutDirection: effectiveUserInterfaceLayoutDirection
        )
        guard observedLayout != lastObservedLayout else {
            return
        }

        lastObservedLayout = observedLayout
        guard isObservingChanges else {
            return
        }
        onLayout()
    }

    private struct ObservedLayout: Equatable {
        let bounds: CGRect
        let safeAreaInsets: UIEdgeInsets
        let layoutDirection: UIUserInterfaceLayoutDirection
    }
}
