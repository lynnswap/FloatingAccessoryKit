import Darwin
import ObjectiveC
import UIKit

@MainActor
@available(iOS 26.0, *)
enum UIKitPrivateRuntime {
    private typealias ObjCMsgSendObject = @convention(c) (AnyObject, Selector) -> AnyObject?
    private typealias ObjCMsgSendSetBool = @convention(c) (AnyObject, Selector, CChar) -> Void
    private typealias ObjCMsgSendSetDouble = @convention(c) (AnyObject, Selector, Double) -> Void
    private typealias ObjCMsgSendSetObject = @convention(c) (AnyObject, Selector, AnyObject?) -> Void
    private typealias ObjCMsgSendSetCGRect = @convention(c) (AnyObject, Selector, CGRect) -> Void
    private typealias ObjCMsgSendSetInsets = @convention(c) (AnyObject, Selector, UIEdgeInsets) -> Void
    private typealias ObjCMsgSendObjectInt = @convention(c) (AnyObject, Selector, Int) -> AnyObject?
    private typealias ObjCMsgSendHitTest = @convention(c) (AnyObject, Selector, CGPoint, UIEvent?) -> AnyObject?

    private static let sendObject: ObjCMsgSendObject? = loadObjCMsgSend(as: ObjCMsgSendObject.self)
    private static let sendSetBool: ObjCMsgSendSetBool? = loadObjCMsgSend(as: ObjCMsgSendSetBool.self)
    private static let sendSetDouble: ObjCMsgSendSetDouble? = loadObjCMsgSend(as: ObjCMsgSendSetDouble.self)
    private static let sendSetObject: ObjCMsgSendSetObject? = loadObjCMsgSend(as: ObjCMsgSendSetObject.self)
    private static let sendSetCGRect: ObjCMsgSendSetCGRect? = loadObjCMsgSend(as: ObjCMsgSendSetCGRect.self)
    private static let sendSetInsets: ObjCMsgSendSetInsets? = loadObjCMsgSend(as: ObjCMsgSendSetInsets.self)
    private static let sendObjectInt: ObjCMsgSendObjectInt? = loadObjCMsgSend(as: ObjCMsgSendObjectInt.self)

    private static var didInstallTabBarAnimationSettingsHook = false
    private static var didInstallMorphingViewsHook = false
    private static var didInstallTouchRoutingFix = false
    private static var originalAnimationSettings: ObjCMsgSendObject?
    private static var originalViewsForMorphing: ObjCMsgSendObjectInt?
    private static var originalHitTest: ObjCMsgSendHitTest?
    private static var animationSettingsBlock: Any?
    private static var viewsForMorphingBlock: Any?
    private static var hitTestProbeBlock: Any?
    private static var customAnimationSettingsKey: UInt8 = 0
    private static var managedTabAccessoryControllerKey: UInt8 = 0
    private static var managedTabAccessoryContentViewKey: UInt8 = 0

    static func objectValue(selectorName: String, on object: NSObject?) -> NSObject? {
        let selector = NSSelectorFromString(selectorName)
        guard let object, object.responds(to: selector), let sendObject else {
            return nil
        }
        return sendObject(object, selector) as? NSObject
    }

    static func setBool(_ value: Bool, on object: NSObject?, selectorName: String) {
        let selector = NSSelectorFromString(selectorName)
        guard let object, object.responds(to: selector) else {
            return
        }
        sendSetBool?(object, selector, value ? 1 : 0)
    }

    static func setDouble(_ value: Double, on object: NSObject?, selectorName: String) {
        let selector = NSSelectorFromString(selectorName)
        guard let object, object.responds(to: selector) else {
            return
        }
        sendSetDouble?(object, selector, value)
    }

    static func setObject(_ value: NSObject?, on object: NSObject?, selectorName: String) {
        let selector = NSSelectorFromString(selectorName)
        guard let object, object.responds(to: selector) else {
            return
        }
        sendSetObject?(object, selector, value)
    }

    static func setCGRect(_ value: CGRect, on object: NSObject?, selectorName: String) {
        let selector = NSSelectorFromString(selectorName)
        guard let object, object.responds(to: selector) else {
            return
        }
        sendSetCGRect?(object, selector, value)
    }

    static func setInsets(_ value: UIEdgeInsets, on object: NSObject?, selectorName: String) {
        let selector = NSSelectorFromString(selectorName)
        guard let object, object.responds(to: selector) else {
            return
        }
        sendSetInsets?(object, selector, value)
    }

    static func perform(_ selectorName: String, on object: NSObject?) {
        let selector = NSSelectorFromString(selectorName)
        guard let object, object.responds(to: selector) else {
            return
        }
        _ = object.perform(selector)
    }

    static func installTabBarAnimationHooks() {
        installTabBarAnimationSettingsHook()
        installTabBarMorphingViewsHook()
    }

    static func installTouchRoutingFix() {
        guard !didInstallTouchRoutingFix else {
            return
        }

        didInstallTouchRoutingFix = true
        swizzleHitTestRoutingFix()
    }

    static func setHasManagedTabAccessoryView(_ value: Bool, on tabBarController: UITabBarController) {
        objc_setAssociatedObject(
            tabBarController,
            &managedTabAccessoryControllerKey,
            value as NSNumber,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }

    static func setIsManagedTabAccessoryContentView(_ value: Bool, on view: UIView) {
        objc_setAssociatedObject(
            view,
            &managedTabAccessoryContentViewKey,
            value as NSNumber,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }

    private static func swizzleHitTestRoutingFix() {
        let selector = NSSelectorFromString("hitTest:withEvent:")
        guard let method = class_getInstanceMethod(UIView.self, selector) else {
            return
        }

        originalHitTest = unsafeBitCast(
            method_getImplementation(method),
            to: ObjCMsgSendHitTest.self
        )

        let block: @convention(block) (UIView, CGPoint, UIEvent?) -> UIView? = { view, point, event in
            MainActor.assumeIsolated {
                let originalResult = originalHitTest?(view, selector, point, event) as? UIView
                return adjustedAccessoryContainerHitTestResult(
                    view: view,
                    point: point,
                    originalResult: originalResult
                )
            }
        }

        hitTestProbeBlock = block
        method_setImplementation(method, imp_implementationWithBlock(block))
    }

    private static func adjustedAccessoryContainerHitTestResult(
        view: UIView,
        point: CGPoint,
        originalResult: UIView?
    ) -> UIView? {
        guard view.privateClassName.contains("UITabAccessoryContainer"),
              originalResult === view,
              !pointHitsAccessoryContent(point, in: view) else {
            return originalResult
        }

        return nil
    }

    private static func pointHitsAccessoryContent(_ point: CGPoint, in accessoryContainer: UIView) -> Bool {
        accessoryContainer.subviews.contains { subview in
            guard !subview.isHidden, subview.alpha > 0.01, subview.isUserInteractionEnabled else {
                return false
            }

            let subviewPoint = accessoryContainer.convert(point, to: subview)
            return subview.point(inside: subviewPoint, with: nil)
        }
    }

    private static func installTabBarAnimationSettingsHook() {
        guard !didInstallTabBarAnimationSettingsHook,
              let layoutManagerClass = privateClass(named: "_UITabBarContentLayoutManager") else {
            return
        }

        didInstallTabBarAnimationSettingsHook = true
        swizzleAnimationSettings(on: layoutManagerClass)
    }

    private static func swizzleAnimationSettings(on layoutManagerClass: AnyClass) {
        let selector = NSSelectorFromString("animationSettings")
        guard let method = class_getInstanceMethod(layoutManagerClass, selector) else {
            return
        }

        originalAnimationSettings = unsafeBitCast(
            method_getImplementation(method),
            to: ObjCMsgSendObject.self
        )

        let block: @convention(block) (AnyObject) -> AnyObject? = { manager in
            var resolvedSettings: AnyObject?
            MainActor.assumeIsolated {
                guard let settings = originalAnimationSettings?(manager, selector) as? NSObject else {
                    return
                }

                guard isManagedTabAccessoryLayoutManager(manager),
                      let customSettings = customAnimationSettings(for: manager, source: settings) else {
                    resolvedSettings = settings
                    return
                }
                resolvedSettings = customSettings
            }
            return resolvedSettings
        }

        animationSettingsBlock = block
        method_setImplementation(method, imp_implementationWithBlock(block))
    }

    private static func installTabBarMorphingViewsHook() {
        guard !didInstallMorphingViewsHook,
              let visualProviderClass = privateClass(named: "_UITabBarVisualProvider_Floating") else {
            return
        }

        didInstallMorphingViewsHook = true
        swizzleViewsForMorphing(on: visualProviderClass)
    }

    private static func swizzleViewsForMorphing(on visualProviderClass: AnyClass) {
        let selector = NSSelectorFromString("viewsForMorphingToTarget:")
        guard let method = class_getInstanceMethod(visualProviderClass, selector) else {
            return
        }

        originalViewsForMorphing = unsafeBitCast(
            method_getImplementation(method),
            to: ObjCMsgSendObjectInt.self
        )

        let block: @convention(block) (AnyObject, Int) -> AnyObject? = { provider, target in
            var resolvedViews: AnyObject?
            MainActor.assumeIsolated {
                guard let result = originalViewsForMorphing?(provider, selector, target) else {
                    return
                }

                resolvedViews = filteredMorphingViews(result) ?? result
            }
            return resolvedViews
        }

        viewsForMorphingBlock = block
        method_setImplementation(method, imp_implementationWithBlock(block))
    }

    private static func filteredMorphingViews(_ result: AnyObject) -> AnyObject? {
        guard let views = result as? [AnyObject] else {
            return nil
        }

        let filteredViews = views.filter { object in
            guard let view = object as? UIView else {
                return true
            }
            return !containsManagedTabAccessoryContentView(view)
        }

        guard filteredViews.count != views.count else {
            return nil
        }
        return filteredViews as NSArray
    }

    private static func containsManagedTabAccessoryContentView(_ view: UIView) -> Bool {
        if (objc_getAssociatedObject(view, &managedTabAccessoryContentViewKey) as? NSNumber)?.boolValue == true {
            return true
        }

        return view.subviews.contains { containsManagedTabAccessoryContentView($0) }
    }

    private static func isManagedTabAccessoryLayoutManager(_ manager: AnyObject) -> Bool {
        guard let manager = manager as? NSObject,
              let host = objectValue(selectorName: "host", on: manager),
              let tabBarController = objectValue(selectorName: "tabBarController", on: host) as? UITabBarController else {
            return false
        }

        return (objc_getAssociatedObject(
            tabBarController,
            &managedTabAccessoryControllerKey
        ) as? NSNumber)?.boolValue == true
    }

    private static func customAnimationSettings(for manager: AnyObject, source: NSObject) -> NSObject? {
        if let existing = objc_getAssociatedObject(manager, &customAnimationSettingsKey) as? NSObject {
            return existing
        }

        guard let settings = copyObject(source) ?? instantiateLike(source, initializerName: "initWithDefaultValues") else {
            return nil
        }

        applyManagedAccessoryAnimationTuning(to: settings, source: source)
        objc_setAssociatedObject(
            manager,
            &customAnimationSettingsKey,
            settings,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        return settings
    }

    private static func applyManagedAccessoryAnimationTuning(to settings: NSObject, source: NSObject) {
        let primarySpringKeys = [
            "collapseIntermediateSpring",
            "collapseFinalSpring",
            "expandIntermediateSpring",
            "expandFinalSpring"
        ]
        primarySpringKeys.forEach { key in
            replaceSpring(
                named: key,
                on: settings,
                source: source,
                dampingRatio: 1.0,
                response: 0.22
            )
        }

        let trackingSpringKeys = [
            "scrollAwayHintResetSpring",
            "scrollAwayProgressSpring",
            "scrollAwayTrackingProgressSpring"
        ]
        trackingSpringKeys.forEach { key in
            replaceSpring(
                named: key,
                on: settings,
                source: source,
                dampingRatio: 1.0,
                response: 0.18
            )
        }

        setDouble(0, on: settings, selectorName: "setCollapseFinalSpringDelay:")
        setDouble(0, on: settings, selectorName: "setExpandFinalSpringDelay:")
        setDouble(1, on: settings, selectorName: "setScrollAwayProgressMultiplier:")
    }

    private static func replaceSpring(
        named key: String,
        on settings: NSObject,
        source: NSObject,
        dampingRatio: Double,
        response: Double
    ) {
        guard let sourceSpring = objectValue(selectorName: key, on: source),
              let spring = copyObject(sourceSpring) ?? instantiateLike(sourceSpring, initializerName: "initWithDefaultValues") else {
            return
        }

        tuneSpring(spring, dampingRatio: dampingRatio, response: response)
        setObject(spring, on: settings, selectorName: "set\(key.capitalizedFirstLetter):")
    }

    private static func tuneSpring(_ spring: NSObject, dampingRatio: Double, response: Double) {
        setDouble(dampingRatio, on: spring, selectorName: "setDampingRatio:")
        setDouble(response, on: spring, selectorName: "setResponse:")
        setDouble(dampingRatio, on: spring, selectorName: "setTrackingDampingRatio:")
        setDouble(response, on: spring, selectorName: "setTrackingResponse:")
        setDouble(0, on: spring, selectorName: "setRetargetImpulse:")
        setDouble(0, on: spring, selectorName: "setTrackingRetargetImpulse:")
    }

    private static func copyObject(_ object: NSObject) -> NSObject? {
        guard object.responds(to: NSSelectorFromString("copy")) else {
            return nil
        }
        return objectValue(selectorName: "copy", on: object)
    }

    private static func instantiateLike(_ object: NSObject, initializerName: String) -> NSObject? {
        guard let objectClass = object_getClass(object),
              let allocated = sendObject?(objectClass, NSSelectorFromString("alloc")) as? NSObject else {
            return nil
        }

        return objectValue(selectorName: initializerName, on: allocated) ?? allocated
    }

    private static func privateClass(named name: String) -> AnyClass? {
        [
            name,
            "UIKit.\(name)",
            "UIKitCore.\(name)",
            "UIKitCore_Internal.\(name)"
        ]
        .lazy
        .compactMap(NSClassFromString)
        .first
    }

    private static func loadObjCMsgSend<T>(as type: T.Type) -> T? {
        guard let handle = dlopen(nil, RTLD_NOW),
              let symbol = dlsym(handle, "objc_msgSend") else {
            return nil
        }
        return unsafeBitCast(symbol, to: type)
    }
}

private extension String {
    var capitalizedFirstLetter: String {
        guard let first else {
            return self
        }
        return first.uppercased() + dropFirst()
    }
}
