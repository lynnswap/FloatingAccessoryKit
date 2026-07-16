import Testing
import UIKit
@testable import FloatingAccessoryKit

@MainActor
@Suite
struct AccessoryContentHostViewTests {
    @Test func intrinsicContentFillsManagedHost() {
        let contentView = FixedSizeView(size: CGSize(width: 84, height: 42))
        let contentHostView = AccessoryContentHostView(
            contentView: contentView,
            preferredSizeDidChange: {}
        )
        contentHostView.frame = CGRect(x: 0, y: 0, width: 96, height: 48)

        contentHostView.layoutIfNeeded()

        #expect(contentView.frame == contentHostView.bounds)
    }

    @Test func requiredContentSizeRemainsCenteredWithinManagedHost() {
        let contentView = UIView()
        NSLayoutConstraint.activate([
            contentView.widthAnchor.constraint(equalToConstant: 84),
            contentView.heightAnchor.constraint(equalToConstant: 42)
        ])
        let contentHostView = AccessoryContentHostView(
            contentView: contentView,
            preferredSizeDidChange: {}
        )
        contentHostView.frame = CGRect(x: 0, y: 0, width: 96, height: 48)

        contentHostView.layoutIfNeeded()

        #expect(contentView.bounds.size == CGSize(width: 84, height: 42))
        #expect(contentView.center == CGPoint(x: 48, y: 24))
    }

    @Test func deinitializationRestoresConsumerAutoresizing() {
        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = true
        weak var weakContentHostView: AccessoryContentHostView?

        do {
            let contentHostView = AccessoryContentHostView(
                contentView: contentView,
                preferredSizeDidChange: {}
            )
            weakContentHostView = contentHostView
            #expect(contentView.translatesAutoresizingMaskIntoConstraints == false)
        }

        #expect(weakContentHostView == nil)
        #expect(contentView.translatesAutoresizingMaskIntoConstraints == true)
    }
}
