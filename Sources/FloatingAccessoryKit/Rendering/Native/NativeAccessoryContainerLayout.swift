import ObjectiveC
import UIKit

@MainActor
@available(iOS 26.0, *)
enum NativeAccessoryContainerLayout {
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
        let state = layoutState(for: container) ?? LayoutState()
        if let previousHost = state.host,
           hostState(for: previousHost) === state {
            objc_setAssociatedObject(
                previousHost,
                &hostStateKey,
                nil,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
        state.horizontalConstraint?.isActive = false
        state.horizontalConstraint = nil
        state.horizontalPlacement = nil
        state.container = container
        state.contentView = contentView
        state.position = position
        state.layoutDirection = container.effectiveUserInterfaceLayoutDirection

        if let host = layoutHost(containing: container),
           installIfNeeded(for: type(of: host)) {
            state.host = host
            state.systemFrame = systemFrame(for: container, in: host, state: state)
            state.accessoryElement = accessoryElement(
                in: host,
                matching: container,
                state: state
            )
            objc_setAssociatedObject(
                host,
                &hostStateKey,
                state,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        } else {
            state.host = nil
            state.systemFrame = nil
            state.accessoryElement = nil
        }

        objc_setAssociatedObject(
            container,
            &containerStateKey,
            state,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        updateHorizontalConstraint(for: state)
        requestLayout(for: state)
    }

    static func update(
        container: UIView,
        contentWidth: CGFloat,
        position: TabBarAccessoryController.Position
    ) {
        guard let state = layoutState(for: container) else {
            return
        }

        state.preferredWidth = contentWidth
        state.position = position
        state.layoutDirection = container.effectiveUserInterfaceLayoutDirection
        updateHorizontalConstraint(for: state)
        requestLayout(for: state)
    }

    static func unregister(container: UIView?) {
        guard let container else {
            return
        }

        guard let state = layoutState(for: container) else {
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
        state.horizontalConstraint?.isActive = false
        state.horizontalConstraint = nil
        state.horizontalPlacement = nil

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
        } else {
            container.superview?.setNeedsLayout()
            container.superview?.layoutIfNeeded()
        }
    }

    static func availableWidth(for container: UIView) -> CGFloat {
        if let state = layoutState(for: container) {
            if let width = state.systemFrame?.width,
               width.isFinite,
               width > 0 {
                return width
            }

            if state.host == nil,
               container.bounds.width.isFinite,
               container.bounds.width > 0 {
                return container.bounds.width
            }
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

    static func availableHeight(for container: UIView) -> CGFloat {
        if let height = layoutState(for: container)?.systemFrame?.height,
           height.isFinite,
           height > 0 {
            return height
        }

        return container.bounds.height
    }

    private static func installIfNeeded(for hostClass: AnyClass) -> Bool {
        let classID = ObjectIdentifier(hostClass)
        guard installedHostClassStates[classID] == nil else {
            return true
        }

        guard let method = class_getInstanceMethod(hostClass, hostedElementFrameSelector),
              let typeEncoding = method_getTypeEncoding(method),
              let originalImplementation = class_getMethodImplementation(hostClass, hostedElementFrameSelector) else {
            FloatingAccessoryDiagnostics.reportOnce(
                id: "native-layout-hook-unavailable-\(NSStringFromClass(hostClass))",
                "Native accessory placement is using content alignment because the hosted-element frame capability is unavailable on \(NSStringFromClass(hostClass))."
            )
            return false
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
        let didAddMethod = class_addMethod(
            hostClass,
            hostedElementFrameSelector,
            implementation,
            typeEncoding
        )
        if !didAddMethod,
           let method = class_getInstanceMethod(hostClass, hostedElementFrameSelector) {
            method_setImplementation(method, implementation)
        }

        guard didAddMethod
                || class_getMethodImplementation(hostClass, hostedElementFrameSelector) == implementation else {
            FloatingAccessoryDiagnostics.reportOnce(
                id: "native-layout-hook-installation-failed-\(NSStringFromClass(hostClass))",
                "Native accessory placement is using content alignment because the hosted-element frame capability could not be installed on \(NSStringFromClass(hostClass))."
            )
            return false
        }

        installedHostClassStates[classID] = HostClassState(
            originalFrameForHostedElement: originalFrameForHostedElement,
            block: block
        )
        return true
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
        state: LayoutState
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
        state: LayoutState
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

    private static func requestLayout(for state: LayoutState) {
        if let host = state.host {
            host.setNeedsLayout()
            host.layoutIfNeeded()
            return
        }

        guard let container = state.container else {
            return
        }

        container.superview?.setNeedsLayout()
        container.superview?.layoutIfNeeded()
        container.setNeedsLayout()
        container.layoutIfNeeded()
    }

    private static func updateHorizontalConstraint(for state: LayoutState) {
        guard let container = state.container,
              let contentView = state.contentView else {
            state.horizontalConstraint?.isActive = false
            state.horizontalConstraint = nil
            state.horizontalPlacement = nil
            return
        }

        let placement = HorizontalPlacement(
            position: state.position,
            usesHostedElementFrame: state.host != nil
        )
        guard state.horizontalPlacement != placement else {
            return
        }

        state.horizontalConstraint?.isActive = false
        let constraint: NSLayoutConstraint
        switch placement {
        case .leading:
            constraint = contentView.leadingAnchor.constraint(
                equalTo: container.leadingAnchor
            )
        case .center:
            constraint = contentView.centerXAnchor.constraint(
                equalTo: container.centerXAnchor
            )
        case .trailing:
            constraint = contentView.trailingAnchor.constraint(
                equalTo: container.trailingAnchor
            )
        }
        constraint.identifier = "FloatingAccessoryKit.contentHorizontalPlacement"
        constraint.isActive = true
        state.horizontalConstraint = constraint
        state.horizontalPlacement = placement
    }

    private static func resolvedFrame(from frame: CGRect, state: LayoutState) -> CGRect {
        guard shouldAdjustFrame(for: state) else {
            return frame
        }

        return adjustedFrame(from: frame, state: state)
    }

    private static func shouldAdjustFrame(for state: LayoutState) -> Bool {
        guard let environment = state.contentView?.traitCollection.tabAccessoryEnvironment else {
            return false
        }

        return environment != .none
    }

    private static func adjustedFrame(from frame: CGRect, state: LayoutState) -> CGRect {
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

        let leadingOrigin = frame.minX
        let centerOrigin = centerX(for: frame, state: state) - width / 2
        let trailingOrigin = frame.maxX - width
        let alignment = state.resolvedHorizontalAlignment
        if alignment <= 0.5 {
            adjustedFrame.origin.x = leadingOrigin
                + (centerOrigin - leadingOrigin) * alignment * 2
        } else {
            adjustedFrame.origin.x = centerOrigin
                + (trailingOrigin - centerOrigin) * (alignment - 0.5) * 2
        }

        return adjustedFrame
    }

    private static func centerX(for frame: CGRect, state: LayoutState) -> CGFloat {
        guard let host = state.host,
              host.bounds.width.isFinite,
              host.bounds.width > 0 else {
            return frame.midX
        }

        return host.bounds.midX
    }

    private static func layoutState(for container: UIView) -> LayoutState? {
        objc_getAssociatedObject(container, &containerStateKey) as? LayoutState
    }

    private static func hostState(for host: UIView) -> LayoutState? {
        objc_getAssociatedObject(host, &hostStateKey) as? LayoutState
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

    private final class LayoutState {
        weak var container: UIView?
        weak var contentView: UIView?
        weak var host: UIView?
        var horizontalConstraint: NSLayoutConstraint?
        var horizontalPlacement: HorizontalPlacement?
        var preferredWidth: CGFloat?
        var systemFrame: CGRect?
        var position: TabBarAccessoryController.Position = .trailing
        var layoutDirection: UIUserInterfaceLayoutDirection = .leftToRight
        var accessoryElement: Int?
        var resolvedHorizontalAlignment: CGFloat {
            position.resolvedHorizontalAlignment(for: layoutDirection)
        }

        func matches(element: Int, fallbackElement: Int) -> Bool {
            accessoryElement == element || (accessoryElement == nil && element == fallbackElement)
        }
    }

    private enum HorizontalPlacement: Equatable {
        case leading
        case center
        case trailing

        init(
            position: TabBarAccessoryController.Position,
            usesHostedElementFrame: Bool
        ) {
            if usesHostedElementFrame {
                self = .center
                return
            }

            switch position.horizontalAlignment {
            case 0:
                self = .leading
            case 0.5:
                self = .center
            case 1:
                self = .trailing
            default:
                preconditionFailure("Unsupported native accessory position")
            }
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
