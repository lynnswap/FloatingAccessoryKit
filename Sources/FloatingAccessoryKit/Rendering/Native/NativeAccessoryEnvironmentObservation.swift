import UIKit

@MainActor
@available(iOS 26.0, *)
final class NativeAccessoryEnvironmentObservation {
    private weak var contentHostView: AccessoryContentHostView?
    private let onChange: @MainActor () -> Void
    private var containerFrameObservation: NSKeyValueObservation?
    private var environmentObservation: (any UITraitChangeRegistration)?
    private var lastObservedContainerFrame: CGRect

    init(
        container: UIView,
        contentHostView: AccessoryContentHostView,
        onChange: @escaping @MainActor () -> Void
    ) {
        self.contentHostView = contentHostView
        self.onChange = onChange
        lastObservedContainerFrame = container.frame

        containerFrameObservation = container.observe(
            \.frame,
            options: [.new]
        ) { [weak self] _, change in
            MainActor.assumeIsolated {
                self?.containerFrameDidChange(to: change.newValue)
            }
        }
        environmentObservation = contentHostView.registerForTraitChanges(
            [UITraitTabAccessoryEnvironment.self]
        ) { [weak self] (_: AccessoryContentHostView, _: UITraitCollection) in
            self?.onChange()
        }
    }

    func invalidate() {
        containerFrameObservation?.invalidate()
        containerFrameObservation = nil
        if let environmentObservation {
            contentHostView?.unregisterForTraitChanges(environmentObservation)
        }
        environmentObservation = nil
    }

    private func containerFrameDidChange(to frame: CGRect?) {
        guard let frame,
              frame != lastObservedContainerFrame else {
            return
        }

        lastObservedContainerFrame = frame
        onChange()
    }
}
