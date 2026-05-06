import ObjectiveC
import UIKit

@MainActor
@available(iOS 26.0, *)
enum TabBarAccessoryHitTesting {
    private typealias HitTestIMP = @convention(c) (UIView, Selector, CGPoint, UIEvent?) -> UIView?

    private static var didInstall = false
    private static var originalHitTest: HitTestIMP?
    private static var hitTestBlock: Any?
    private static var passthroughStateKey: UInt8 = 0

    static func register(container: UIView, contentView: UIView) {
        installIfNeeded()
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

    private static func installIfNeeded() {
        guard !didInstall else {
            return
        }

        didInstall = true
        swizzleHitTest()
    }

    private static func swizzleHitTest() {
        let selector = #selector(UIView.hitTest(_:with:))
        guard let method = class_getInstanceMethod(UIView.self, selector) else {
            return
        }

        originalHitTest = unsafeBitCast(
            method_getImplementation(method),
            to: HitTestIMP.self
        )

        let block: @convention(block) (UIView, CGPoint, UIEvent?) -> UIView? = { view, point, event in
            MainActor.assumeIsolated {
                let originalResult = originalHitTest?(view, selector, point, event)
                return adjustedHitTestResult(
                    for: view,
                    point: point,
                    event: event,
                    originalResult: originalResult
                )
            }
        }

        hitTestBlock = block
        method_setImplementation(method, imp_implementationWithBlock(block))
    }

    private static func adjustedHitTestResult(
        for view: UIView,
        point: CGPoint,
        event: UIEvent?,
        originalResult: UIView?
    ) -> UIView? {
        guard originalResult === view,
              let state = objc_getAssociatedObject(view, &passthroughStateKey) as? PassthroughState,
              let contentView = state.contentView else {
            return originalResult
        }

        let contentPoint = view.convert(point, to: contentView)
        return contentView.hitTest(contentPoint, with: event) == nil ? nil : originalResult
    }

    private final class PassthroughState: NSObject {
        weak var contentView: UIView?

        init(contentView: UIView) {
            self.contentView = contentView
        }
    }
}
