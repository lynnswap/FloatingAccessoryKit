import SwiftUI

@available(iOS 26.0, *)
struct TabBarAccessorySwiftUIRoot<Content: SwiftUI.View>: SwiftUI.View {
    private let content: () -> Content

    init(@SwiftUI.ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some SwiftUI.View {
        Group(subviews: Group { content() }) { subviews in
            TabBarAccessorySwiftUILayout {
                ForEach(subviews) { subview in
                    subview
                }
            }
        }
    }
}

@available(iOS 26.0, *)
struct TabBarAccessorySwiftUILayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else {
            return .zero
        }

        let height = resolvedHeight(proposal: proposal, subviews: subviews)
        let totalWidth = subviews.indices.reduce(CGFloat.zero) { result, index in
            result + measuredWidth(for: subviews[index], height: height) + spacingAfter(index, subviews: subviews)
        }

        return CGSize(width: totalWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX

        for index in subviews.indices {
            let width = measuredWidth(for: subviews[index], height: bounds.height)
            subviews[index].place(
                at: CGPoint(x: x + width / 2, y: bounds.midY),
                anchor: .center,
                proposal: ProposedViewSize(width: width, height: bounds.height)
            )
            x += width + spacingAfter(index, subviews: subviews)
        }
    }

    private func resolvedHeight(proposal: ProposedViewSize, subviews: Subviews) -> CGFloat {
        if let height = proposal.height, height.isFinite, height > 0 {
            return height
        }

        return subviews.reduce(CGFloat.zero) { result, subview in
            max(result, subview.sizeThatFits(.unspecified).height)
        }
    }

    private func measuredWidth(for subview: Subviews.Element, height: CGFloat) -> CGFloat {
        let fittingSize = subview.sizeThatFits(ProposedViewSize(width: nil, height: height))
        guard fittingSize.width.isFinite, fittingSize.width > 0 else {
            return height
        }

        return max(fittingSize.width, height)
    }

    private func spacingAfter(_ index: Subviews.Index, subviews: Subviews) -> CGFloat {
        let nextIndex = subviews.index(after: index)
        guard nextIndex < subviews.endIndex else {
            return 0
        }

        return subviews[index].spacing.distance(to: subviews[nextIndex].spacing, along: .horizontal)
    }
}
