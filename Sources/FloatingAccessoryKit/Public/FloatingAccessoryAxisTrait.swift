import UIKit

/// A trait that tells accessory content which way to lay out its items.
///
/// The value is `.horizontal` while the accessory sits beside or above a
/// horizontal tab bar, and `.vertical` while it sits in the column of a
/// vertical tab bar. Read it through
/// ``UIKit/UITraitCollection/floatingAccessoryAxis`` and observe it with
/// `registerForTraitChanges(_:handler:)`.
public struct FloatingAccessoryAxisTrait: UITraitDefinition {
    public static let defaultValue: NSLayoutConstraint.Axis = .horizontal
}

public extension UITraitCollection {
    /// The axis along which floating-accessory content lays out its items.
    var floatingAccessoryAxis: NSLayoutConstraint.Axis {
        self[FloatingAccessoryAxisTrait.self]
    }
}

extension UIMutableTraits {
    var floatingAccessoryAxis: NSLayoutConstraint.Axis {
        get { self[FloatingAccessoryAxisTrait.self] }
        set { self[FloatingAccessoryAxisTrait.self] = newValue }
    }
}
