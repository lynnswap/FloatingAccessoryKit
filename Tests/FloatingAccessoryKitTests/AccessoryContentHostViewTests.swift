import Testing
import UIKit
@testable import FloatingAccessoryKit

@MainActor
@Suite
struct AccessoryContentHostViewTests {
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
