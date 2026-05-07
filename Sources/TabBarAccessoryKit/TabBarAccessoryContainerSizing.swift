import ObjectiveC
import UIKit

@MainActor
@available(iOS 26.0, *)
enum TabBarAccessoryContainerSizing {
    private typealias HostedElementFrameIMP = @convention(c) (UIView, Selector, Int, Int) -> CGRect

    private static let hostedElementFrameSelector = NSSelectorFromString([":", "options", ":", "frameForHostedElement"].reversed().joined())
    private static let fallbackAccessoryElement = 2
    private static var installedHostClassStates: [ObjectIdentifier: HostClassState] = [:]
    private static var containerStateKey: UInt8 = 0
    private static var hostStateKey: UInt8 = 0

    static func register(
        container: UIView,
        contentView: UIView,
        position: TabBarAccessoryController.Position
    ) {
        guard let host = layoutHost(containing: container) else {
            return
        }

        installIfNeeded(for: type(of: host))

        let state = sizingState(for: container) ?? SizingState()
        state.container = container
        state.contentView = contentView
        state.host = host
        state.position = position
        state.layoutDirection = container.effectiveUserInterfaceLayoutDirection
        state.systemFrame = systemFrame(for: container, in: host, state: state)
        state.accessoryElement = accessoryElement(in: host, matching: container, state: state)

        objc_setAssociatedObject(
            container,
            &containerStateKey,
            state,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        objc_setAssociatedObject(
            host,
            &hostStateKey,
            state,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        requestLayout(for: state)
    }

    static func update(
        container: UIView,
        contentWidth: CGFloat,
        position: TabBarAccessoryController.Position
    ) {
        guard let state = sizingState(for: container) else {
            return
        }

        state.preferredWidth = contentWidth
        state.position = position
        state.layoutDirection = container.effectiveUserInterfaceLayoutDirection
        requestLayout(for: state)
    }

    static func unregister(container: UIView?) {
        guard let container else {
            return
        }

        guard let state = sizingState(for: container) else {
            objc_setAssociatedObject(
                container,
                &containerStateKey,
                nil,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            return
        }

        objc_setAssociatedObject(
            container,
            &containerStateKey,
            nil,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )

        if let host = state.host,
           hostState(for: host) === state {
            objc_setAssociatedObject(
                host,
                &hostStateKey,
                nil,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            host.setNeedsLayout()
            host.layoutIfNeeded()
        }
    }

    static func availableWidth(for container: UIView) -> CGFloat {
        if let width = sizingState(for: container)?.systemFrame?.width,
           width.isFinite,
           width > 0 {
            return width
        }

        let candidates = [
            container.superview?.bounds.width,
            container.bounds.width
        ]

        return candidates
            .compactMap { $0 }
            .filter { $0.isFinite && $0 > 0 }
            .max() ?? container.bounds.width
    }

    private static func installIfNeeded(for hostClass: AnyClass) {
        let classID = ObjectIdentifier(hostClass)
        guard installedHostClassStates[classID] == nil else {
            return
        }

        guard let method = class_getInstanceMethod(hostClass, hostedElementFrameSelector),
              let typeEncoding = method_getTypeEncoding(method),
              let originalImplementation = class_getMethodImplementation(hostClass, hostedElementFrameSelector) else {
            return
        }

        let originalFrameForHostedElement = unsafeBitCast(
            originalImplementation,
            to: HostedElementFrameIMP.self
        )

        let block: @convention(block) (UIView, Int, Int) -> CGRect = { host, element, options in
            MainActor.assumeIsolated {
                let systemFrame = originalFrameForHostedElement(
                    host,
                    hostedElementFrameSelector,
                    element,
                    options
                )

                guard let state = hostState(for: host),
                      state.matches(element: element, fallbackElement: fallbackAccessoryElement) else {
                    return systemFrame
                }

                state.systemFrame = systemFrame
                if state.accessoryElement == nil,
                   !systemFrame.isEmpty {
                    state.accessoryElement = element
                }
                return resolvedFrame(from: systemFrame, state: state)
            }
        }

        let implementation = imp_implementationWithBlock(block)
        if !class_addMethod(hostClass, hostedElementFrameSelector, implementation, typeEncoding),
           let method = class_getInstanceMethod(hostClass, hostedElementFrameSelector) {
            method_setImplementation(method, implementation)
        }

        installedHostClassStates[classID] = HostClassState(
            originalFrameForHostedElement: originalFrameForHostedElement,
            block: block
        )
    }

    private static func layoutHost(containing container: UIView) -> UIView? {
        var view = container.superview
        while let currentView = view {
            if currentView.responds(to: hostedElementFrameSelector) {
                return currentView
            }

            view = currentView.superview
        }

        return nil
    }

    private static func systemFrame(
        for container: UIView,
        in host: UIView,
        state: SizingState
    ) -> CGRect {
        if let accessoryElement = state.accessoryElement,
           let frame = originalFrameForHostedElement(
            in: host,
            element: accessoryElement,
            options: 0
           ) {
            return frame
        }

        let containerFrame = host.convert(container.bounds, from: container)
        guard !containerFrame.isEmpty else {
            return container.frame
        }

        return containerFrame
    }

    private static func accessoryElement(
        in host: UIView,
        matching container: UIView,
        state: SizingState
    ) -> Int? {
        if let accessoryElement = state.accessoryElement {
            return accessoryElement
        }

        let containerFrame = host.convert(container.bounds, from: container)
        guard !containerFrame.isEmpty else {
            return nil
        }

        for element in 0...8 {
            guard let frame = originalFrameForHostedElement(
                in: host,
                element: element,
                options: 0
            ),
            !frame.isEmpty else {
                continue
            }

            if frame.isNearlyEqual(to: containerFrame) {
                return element
            }
        }

        return fallbackAccessoryElement
    }

    private static func originalFrameForHostedElement(
        in host: UIView,
        element: Int,
        options: Int
    ) -> CGRect? {
        installedHostClassStates[ObjectIdentifier(type(of: host))]?.originalFrameForHostedElement(
            host,
            hostedElementFrameSelector,
            element,
            options
        )
    }

    private static func requestLayout(for state: SizingState) {
        guard let host = state.host else {
            return
        }

        host.setNeedsLayout()
        host.layoutIfNeeded()
    }

    private static func resolvedFrame(from frame: CGRect, state: SizingState) -> CGRect {
        guard shouldAdjustFrame(for: state) else {
            return frame
        }

        return adjustedFrame(from: frame, state: state)
    }

    private static func shouldAdjustFrame(for state: SizingState) -> Bool {
        guard let environment = state.contentView?.traitCollection.tabAccessoryEnvironment else {
            return false
        }

        return environment != .none
    }

    private static func adjustedFrame(from frame: CGRect, state: SizingState) -> CGRect {
        guard let preferredWidth = state.preferredWidth,
              preferredWidth.isFinite,
              preferredWidth > 0,
              frame.width.isFinite,
              frame.width > 0 else {
            return frame
        }

        let width = min(ceil(preferredWidth), frame.width)
        guard abs(frame.width - width) > 0.5 else {
            return frame
        }

        var adjustedFrame = frame
        adjustedFrame.size.width = width

        switch state.resolvedPosition {
        case .leading:
            break
        case .center:
            adjustedFrame.origin.x = centerX(for: frame, state: state) - width / 2
        case .trailing:
            adjustedFrame.origin.x = frame.maxX - width
        }

        return adjustedFrame
    }

    private static func centerX(for frame: CGRect, state: SizingState) -> CGFloat {
        guard let host = state.host,
              host.bounds.width.isFinite,
              host.bounds.width > 0 else {
            return frame.midX
        }

        return host.bounds.midX
    }

    private static func sizingState(for container: UIView) -> SizingState? {
        objc_getAssociatedObject(container, &containerStateKey) as? SizingState
    }

    private static func hostState(for host: UIView) -> SizingState? {
        objc_getAssociatedObject(host, &hostStateKey) as? SizingState
    }

    private final class HostClassState {
        let originalFrameForHostedElement: HostedElementFrameIMP
        let block: Any

        init(
            originalFrameForHostedElement: @escaping HostedElementFrameIMP,
            block: Any
        ) {
            self.originalFrameForHostedElement = originalFrameForHostedElement
            self.block = block
        }
    }

    private final class SizingState {
        weak var container: UIView?
        weak var contentView: UIView?
        weak var host: UIView?
        var preferredWidth: CGFloat?
        var systemFrame: CGRect?
        var position: TabBarAccessoryController.Position = .trailing
        var layoutDirection: UIUserInterfaceLayoutDirection = .leftToRight
        var accessoryElement: Int?
        var resolvedPosition: TabBarAccessoryController.Position {
            guard position != .center,
                  layoutDirection == .rightToLeft else {
                return position
            }

            return position == .leading ? .trailing : .leading
        }

        func matches(element: Int, fallbackElement: Int) -> Bool {
            accessoryElement == element || (accessoryElement == nil && element == fallbackElement)
        }
    }
}

private extension CGRect {
    func isNearlyEqual(to other: CGRect) -> Bool {
        abs(origin.x - other.origin.x) <= 0.5
            && abs(origin.y - other.origin.y) <= 0.5
            && abs(size.width - other.size.width) <= 0.5
            && abs(size.height - other.size.height) <= 0.5
    }
}
