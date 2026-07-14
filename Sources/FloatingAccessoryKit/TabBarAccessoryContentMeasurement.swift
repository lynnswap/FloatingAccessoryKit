import UIKit

@MainActor
struct TabBarAccessoryContentMeasurement {
    enum WidthPolicy {
        case intrinsicAspect
        case proposedHeight
    }

    static func width(
        for view: UIView,
        proposedHeight: CGFloat,
        policy: WidthPolicy
    ) -> CGFloat {
        let naturalFittingSize = view.systemLayoutSizeFitting(
            UIView.layoutFittingCompressedSize,
            withHorizontalFittingPriority: .fittingSizeLevel,
            verticalFittingPriority: .fittingSizeLevel
        )
        if isNearlySquare(naturalFittingSize) {
            return proposedHeight
        }

        let proposedHeightFittingSize = view.systemLayoutSizeFitting(
            CGSize(
                width: UIView.layoutFittingCompressedSize.width,
                height: proposedHeight
            ),
            withHorizontalFittingPriority: .fittingSizeLevel,
            verticalFittingPriority: .required
        )
        let idealSize = view.sizeThatFits(
            CGSize(
                width: UIView.layoutFittingExpandedSize.width,
                height: proposedHeight
            )
        )
        let intrinsicSize = view.intrinsicContentSize
        let candidates: [CGSize]
        switch policy {
        case .intrinsicAspect where hasIntrinsicSize(intrinsicSize):
            candidates = [
                idealSize,
                proposedHeightFittingSize,
                naturalFittingSize,
                intrinsicSize
            ]
        case .intrinsicAspect, .proposedHeight:
            candidates = [
                proposedHeightFittingSize,
                idealSize,
                naturalFittingSize,
                intrinsicSize
            ]
        }

        return candidates.lazy
            .compactMap { preferredWidth(forHeight: proposedHeight, fittingSize: $0) }
            .first
            ?? proposedHeight
    }

    private static func preferredWidth(
        forHeight height: CGFloat,
        fittingSize: CGSize
    ) -> CGFloat? {
        if preferredDimension(fittingSize.width) != nil,
           preferredDimension(fittingSize.height) != nil {
            return height * fittingSize.width / fittingSize.height
        }

        return preferredDimension(fittingSize.width)
    }

    private static func isNearlySquare(_ size: CGSize) -> Bool {
        guard preferredDimension(size.width) != nil,
              preferredDimension(size.height) != nil else {
            return false
        }
        return abs(size.width - size.height) <= 0.5
    }

    private static func hasIntrinsicSize(_ size: CGSize) -> Bool {
        preferredDimension(size.width) != nil
            && preferredDimension(size.height) != nil
    }

    private static func preferredDimension(_ value: CGFloat) -> CGFloat? {
        guard value != UIView.noIntrinsicMetric,
              value.isFinite,
              value > 0 else {
            return nil
        }
        return value
    }
}
