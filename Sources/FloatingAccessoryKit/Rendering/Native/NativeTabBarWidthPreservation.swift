import ObjectiveC
import UIKit

/// Keeps a tab bar at the width that fits its items while it has a bottom
/// accessory.
///
/// UIKit tells the tab bar's visual provider which elements the tab bar
/// hosts, and a provider that hosts the accessory stretches the tab bar to
/// the accessory's width. Preservation withholds the accessory from the
/// elements a provider receives; UIKit lays the accessory out by itself
/// either way.
@MainActor
@available(iOS 26.0, *)
enum NativeTabBarWidthPreservation {
    private typealias HostedElementsGetterIMP = @convention(c) (NSObject, Selector) -> Int
    private typealias HostedElementsSetterIMP = @convention(c) (NSObject, Selector, Int) -> Void

    private static let visualProviderName = ["Provider", "_visual"].reversed().joined()
    private static let hostedElementsSelector = NSSelectorFromString(["Elements", "hosted"].reversed().joined())
    private static let setHostedElementsSelector = NSSelectorFromString([":", "Elements", "Hosted", "set"].reversed().joined())
    private static let accessoryElements = 1 << 2
    private static var installedClassStates: [ObjectIdentifier: ClassState] = [:]
    private static var providerStateKey: UInt8 = 0

    /// Starts or stops preserving the tab bar's width.
    ///
    /// UIKit can replace a tab bar's visual provider, so call this again
    /// whenever the tab bar's layout may have changed. Repeating a call has
    /// no further effect.
    static func setPreserved(_ isPreserved: Bool, for tabBar: UITabBar) {
        guard let provider = visualProvider(of: tabBar),
              setPreserved(isPreserved, forVisualProvider: provider) else {
            return
        }

        // The frame UIKit gives the accessory depends on the hosted elements
        // too, and the view that computes it is an ancestor of the tab bar.
        for view in sequence(first: tabBar, next: \.superview) {
            view.setNeedsLayout()
        }
    }

    /// Returns whether the provider's hosted elements changed.
    @discardableResult
    static func setPreserved(
        _ isPreserved: Bool,
        forVisualProvider provider: NSObject
    ) -> Bool {
        guard isPreserved else {
            guard let state = providerState(for: provider),
                  let classState = installedClassState(for: provider) else {
                return false
            }

            objc_setAssociatedObject(
                provider,
                &providerStateKey,
                nil,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            let hostedElements = hostedElements(of: provider)
            guard hostedElements != state.requestedHostedElements else {
                return false
            }
            classState.originalSetHostedElements(
                provider,
                setHostedElementsSelector,
                state.requestedHostedElements
            )
            return true
        }

        guard let classState = installIfNeeded(for: provider) else {
            return false
        }

        let hostedElements = hostedElements(of: provider)
        if providerState(for: provider) == nil {
            objc_setAssociatedObject(
                provider,
                &providerStateKey,
                ProviderState(requestedHostedElements: hostedElements),
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }

        guard hostedElements & accessoryElements != 0 else {
            return false
        }
        classState.originalSetHostedElements(
            provider,
            setHostedElementsSelector,
            hostedElements & ~accessoryElements
        )
        return true
    }

    private static func visualProvider(of tabBar: UITabBar) -> NSObject? {
        guard let ivar = class_getInstanceVariable(UITabBar.self, visualProviderName),
              let typeEncoding = ivar_getTypeEncoding(ivar),
              String(cString: typeEncoding).hasPrefix("@") else {
            FloatingAccessoryDiagnostics.reportOnce(
                id: "native-tab-bar-width-provider-unavailable",
                "The tab bar keeps UIKit's width because its visual provider is unavailable."
            )
            return nil
        }

        return object_getIvar(tabBar, ivar) as? NSObject
    }

    private static func installedClassState(for provider: NSObject) -> ClassState? {
        var currentClass: AnyClass? = type(of: provider)
        while let candidate = currentClass {
            if let classState = installedClassStates[ObjectIdentifier(candidate)] {
                return classState
            }
            currentClass = class_getSuperclass(candidate)
        }
        return nil
    }

    /// Replaces the setter on the class that implements it, so a provider
    /// passes through one replacement however deep its class is.
    private static func installIfNeeded(for provider: NSObject) -> ClassState? {
        if let classState = installedClassState(for: provider) {
            return classState
        }

        let providerClass: AnyClass = type(of: provider)
        guard let getter = class_getInstanceMethod(providerClass, hostedElementsSelector),
              let setter = class_getInstanceMethod(providerClass, setHostedElementsSelector),
              hasIntegerEncoding(method_copyReturnType(getter)),
              method_getNumberOfArguments(setter) == 3,
              hasIntegerEncoding(method_copyArgumentType(setter, 2)) else {
            FloatingAccessoryDiagnostics.reportOnce(
                id: "native-tab-bar-width-hook-unavailable-\(NSStringFromClass(providerClass))",
                "The tab bar keeps UIKit's width because the hosted-elements capability is unavailable on \(NSStringFromClass(providerClass))."
            )
            return nil
        }

        var implementingClass: AnyClass = providerClass
        while let superclass = class_getSuperclass(implementingClass),
              class_getInstanceMethod(superclass, setHostedElementsSelector) == setter {
            implementingClass = superclass
        }

        let originalSetHostedElements = unsafeBitCast(
            method_getImplementation(setter),
            to: HostedElementsSetterIMP.self
        )
        let block: @convention(block) (NSObject, Int) -> Void = { provider, hostedElements in
            MainActor.assumeIsolated {
                guard let state = providerState(for: provider) else {
                    originalSetHostedElements(
                        provider,
                        setHostedElementsSelector,
                        hostedElements
                    )
                    return
                }

                state.requestedHostedElements = hostedElements
                originalSetHostedElements(
                    provider,
                    setHostedElementsSelector,
                    hostedElements & ~accessoryElements
                )
            }
        }
        method_setImplementation(setter, imp_implementationWithBlock(block))

        let classState = ClassState(
            originalSetHostedElements: originalSetHostedElements,
            block: block
        )
        installedClassStates[ObjectIdentifier(implementingClass)] = classState
        return classState
    }

    /// Reads the value through the provider's own class, which may override
    /// the getter of the class that implements the setter.
    private static func hostedElements(of provider: NSObject) -> Int {
        let implementation = class_getMethodImplementation(
            type(of: provider),
            hostedElementsSelector
        )
        return unsafeBitCast(implementation, to: HostedElementsGetterIMP.self)(
            provider,
            hostedElementsSelector
        )
    }

    private static func hasIntegerEncoding(
        _ typeEncoding: UnsafeMutablePointer<CChar>?
    ) -> Bool {
        guard let typeEncoding else {
            return false
        }
        defer { free(typeEncoding) }

        return String(cString: typeEncoding) == "q"
    }

    private static func providerState(for provider: NSObject) -> ProviderState? {
        objc_getAssociatedObject(provider, &providerStateKey) as? ProviderState
    }

    private final class ClassState {
        let originalSetHostedElements: HostedElementsSetterIMP
        let block: Any

        init(
            originalSetHostedElements: @escaping HostedElementsSetterIMP,
            block: Any
        ) {
            self.originalSetHostedElements = originalSetHostedElements
            self.block = block
        }
    }

    private final class ProviderState {
        /// The elements UIKit last asked the provider to host.
        var requestedHostedElements: Int

        init(requestedHostedElements: Int) {
            self.requestedHostedElements = requestedHostedElements
        }
    }
}
