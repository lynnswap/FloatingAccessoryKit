import ObjectiveC
import UIKit

@MainActor
@available(iOS 26.0, *)
enum TabBarAccessoryHitTesting {
    private typealias HitTestIMP = @convention(c) (UIView, Selector, CGPoint, UIEvent?) -> UIView?

    private static var installedClassStates: [ObjectIdentifier: ClassState] = [:]
    private static var passthroughStateKey: UInt8 = 0

    static func register(container: UIView, contentView: UIView) {
        installIfNeeded(for: type(of: container))
        objc_setAssociatedObject(
            container,
            &passthroughStateKey,
            PassthroughState(contentView: contentView),
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }

    static func unregister(container: UIView?) {
        guard let container else {
            return
        }

        objc_setAssociatedObject(
            container,
            &passthroughStateKey,
            nil,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }

    private static func installIfNeeded(for containerClass: AnyClass) {
        guard containerClass !== UIView.self else {
            return
        }

        let classID = ObjectIdentifier(containerClass)
        guard installedClassStates[classID] == nil else {
            return
        }

        let selector = #selector(UIView.hitTest(_:with:))
        guard let baseMethod = class_getInstanceMethod(UIView.self, selector),
              let typeEncoding = method_getTypeEncoding(baseMethod),
              let originalImplementation = class_getMethodImplementation(containerClass, selector) else {
            return
        }

        let originalHitTest = unsafeBitCast(originalImplementation, to: HitTestIMP.self)

        let block: @convention(block) (UIView, CGPoint, UIEvent?) -> UIView? = { view, point, event in
            MainActor.assumeIsolated {
                let originalResult = originalHitTest(view, selector, point, event)
                return adjustedHitTestResult(
                    for: view,
                    point: point,
                    event: event,
                    originalResult: originalResult
                )
            }
        }

        let implementation = imp_implementationWithBlock(block)
        if !class_addMethod(containerClass, selector, implementation, typeEncoding),
           let method = class_getInstanceMethod(containerClass, selector) {
            method_setImplementation(method, implementation)
        }

        installedClassStates[classID] = ClassState(
            originalHitTest: originalHitTest,
            hitTestBlock: block
        )
    }

    private static func adjustedHitTestResult(
        for view: UIView,
        point: CGPoint,
        event: UIEvent?,
        originalResult: UIView?
    ) -> UIView? {
        guard originalResult != nil,
              let state = objc_getAssociatedObject(view, &passthroughStateKey) as? PassthroughState,
              let contentView = state.contentView else {
            return originalResult
        }

        let contentPoint = view.convert(point, to: contentView)
        return contentView.hitTest(contentPoint, with: event)
    }

    private final class ClassState {
        let originalHitTest: HitTestIMP
        let hitTestBlock: Any

        init(originalHitTest: @escaping HitTestIMP, hitTestBlock: Any) {
            self.originalHitTest = originalHitTest
            self.hitTestBlock = hitTestBlock
        }
    }

    private final class PassthroughState: NSObject {
        weak var contentView: UIView?

        init(contentView: UIView) {
            self.contentView = contentView
        }
    }
}
