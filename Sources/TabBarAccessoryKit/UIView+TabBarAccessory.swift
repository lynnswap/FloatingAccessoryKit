import UIKit

@MainActor
@available(iOS 26.0, *)
extension UIView {
    var privateClassName: String {
        NSStringFromClass(type(of: self))
    }

    func descendants(where predicate: (UIView) -> Bool) -> [UIView] {
        subviews.flatMap { subview -> [UIView] in
            let nested = subview.descendants(where: predicate)
            return predicate(subview) ? [subview] + nested : nested
        }
    }
}
