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
            position: .center,
            preferredSizeDidChange: { _ in }
        )
        contentHostView.frame = CGRect(x: 0, y: 0, width: 96, height: 48)

        contentHostView.layoutIfNeeded()

        #expect(contentView.frame == contentHostView.bounds)
    }

    @Test func requiredContentSizeRemainsCenteredAtCenterPosition() {
        let contentView = UIView()
        NSLayoutConstraint.activate([
            contentView.widthAnchor.constraint(equalToConstant: 84),
            contentView.heightAnchor.constraint(equalToConstant: 42)
        ])
        let contentHostView = AccessoryContentHostView(
            contentView: contentView,
            position: .center,
            preferredSizeDidChange: { _ in }
        )
        contentHostView.frame = CGRect(x: 0, y: 0, width: 96, height: 48)

        contentHostView.layoutIfNeeded()

        #expect(contentView.bounds.size == CGSize(width: 84, height: 42))
        #expect(contentView.center == CGPoint(x: 48, y: 24))
    }

    @Test func requiredContentUsesRequestedHorizontalAnchor() {
        let cases: [(
            position: TabBarAccessoryController.Position,
            expectedMinX: CGFloat
        )] = [
            (.leading, 0),
            (.center, 6),
            (.trailing, 12)
        ]

        for testCase in cases {
            let contentView = UIView()
            NSLayoutConstraint.activate([
                contentView.widthAnchor.constraint(equalToConstant: 84),
                contentView.heightAnchor.constraint(equalToConstant: 42)
            ])
            let contentHostView = AccessoryContentHostView(
                contentView: contentView,
                position: testCase.position,
                preferredSizeDidChange: { _ in }
            )
            contentHostView.frame = CGRect(
                x: 0,
                y: 0,
                width: 96,
                height: 48
            )

            contentHostView.layoutIfNeeded()

            #expect(contentView.frame.minX == testCase.expectedMinX)
            #expect(contentView.frame.minY == 3)
        }
    }

    @Test func logicalLeadingContentTracksRightToLeftLayoutDirection() {
        let contentView = UIView()
        NSLayoutConstraint.activate([
            contentView.widthAnchor.constraint(equalToConstant: 84),
            contentView.heightAnchor.constraint(equalToConstant: 42)
        ])
        let contentHostView = AccessoryContentHostView(
            contentView: contentView,
            position: .leading,
            preferredSizeDidChange: { _ in }
        )
        contentHostView.semanticContentAttribute = .forceRightToLeft
        contentHostView.frame = CGRect(x: 0, y: 0, width: 96, height: 48)

        contentHostView.layoutIfNeeded()

        #expect(contentView.frame.maxX == contentHostView.bounds.maxX)
    }

    @Test func positionUpdateReanchorsExistingContent() {
        let contentView = UIView()
        NSLayoutConstraint.activate([
            contentView.widthAnchor.constraint(equalToConstant: 84),
            contentView.heightAnchor.constraint(equalToConstant: 42)
        ])
        let contentHostView = AccessoryContentHostView(
            contentView: contentView,
            position: .center,
            preferredSizeDidChange: { _ in }
        )
        contentHostView.frame = CGRect(x: 0, y: 0, width: 96, height: 48)
        contentHostView.layoutIfNeeded()

        contentHostView.updatePosition(.trailing)
        contentHostView.layoutIfNeeded()

        #expect(contentView.frame.maxX == contentHostView.bounds.maxX)
    }

    @Test func preferredSizeChangesAnimateAfterInitialMeasurement() {
        let contentView = MutableSizeView(
            size: CGSize(width: 84, height: 42)
        )
        var animationRequests: [Bool] = []
        let contentHostView = AccessoryContentHostView(
            contentView: contentView,
            position: .center
        ) { animated in
            animationRequests.append(animated)
        }
        contentHostView.frame = CGRect(x: 0, y: 0, width: 96, height: 48)

        contentHostView.layoutIfNeeded()
        contentView.size = CGSize(width: 126, height: 42)
        contentHostView.setNeedsLayout()
        contentHostView.layoutIfNeeded()

        #expect(animationRequests == [false, true])
    }

    @Test func explicitInvalidationSynchronizesAutomaticObservation() {
        let contentView = MutableSizeView(
            size: CGSize(width: 84, height: 42)
        )
        var animationRequests: [Bool] = []
        let contentHostView = AccessoryContentHostView(
            contentView: contentView,
            position: .center
        ) { animated in
            animationRequests.append(animated)
        }
        contentHostView.frame = CGRect(x: 0, y: 0, width: 96, height: 48)

        contentHostView.layoutIfNeeded()
        contentView.size = CGSize(width: 126, height: 42)
        contentHostView.invalidatePreferredSize(animated: false)
        contentHostView.setNeedsLayout()
        contentHostView.layoutIfNeeded()

        #expect(animationRequests == [false, false])
    }

    @Test func internalConstraintChangeInvalidatesPreferredSizeDuringLayout() {
        let contentView = UIView()
        let width = contentView.widthAnchor.constraint(equalToConstant: 84)
        NSLayoutConstraint.activate([
            width,
            contentView.heightAnchor.constraint(equalToConstant: 42)
        ])
        var animationRequests: [Bool] = []
        let contentHostView = AccessoryContentHostView(
            contentView: contentView,
            position: .center
        ) { animated in
            animationRequests.append(animated)
        }
        contentHostView.frame = CGRect(x: 0, y: 0, width: 96, height: 48)
        let rootViewController = UIViewController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = rootViewController
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        rootViewController.view.addSubview(contentHostView)

        contentHostView.layoutIfNeeded()
        width.constant = 126
        rootViewController.view.layoutIfNeeded()

        #expect(animationRequests == [false, true])
    }

    @Test func deinitializationRestoresConsumerAutoresizing() {
        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = true
        weak var weakContentHostView: AccessoryContentHostView?

        do {
            let contentHostView = AccessoryContentHostView(
                contentView: contentView,
                position: .center,
                preferredSizeDidChange: { _ in }
            )
            weakContentHostView = contentHostView
            #expect(contentView.translatesAutoresizingMaskIntoConstraints == false)
        }

        #expect(weakContentHostView == nil)
        #expect(contentView.translatesAutoresizingMaskIntoConstraints == true)
    }

    @Test func detachingReparentedContentLeavesAutoresizingWithNewOwner() {
        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = true
        let contentHostView = AccessoryContentHostView(
            contentView: contentView,
            position: .center,
            preferredSizeDidChange: { _ in }
        )
        let newOwner = UIView()
        newOwner.addSubview(contentView)

        contentHostView.detachContent(keepingSnapshot: false)

        #expect(contentView.superview === newOwner)
        #expect(contentView.translatesAutoresizingMaskIntoConstraints == false)
    }

    @Test func deinitializationLeavesReparentedAutoresizingWithNewOwner() {
        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = true
        let newOwner = UIView()
        weak var weakContentHostView: AccessoryContentHostView?

        do {
            let contentHostView = AccessoryContentHostView(
                contentView: contentView,
                position: .center,
                preferredSizeDidChange: { _ in }
            )
            weakContentHostView = contentHostView
            newOwner.addSubview(contentView)
        }

        #expect(weakContentHostView == nil)
        #expect(contentView.superview === newOwner)
        #expect(contentView.translatesAutoresizingMaskIntoConstraints == false)
    }

    @Test func detachingReparentedContentPreservesNewOwnerAutoresizingChange() {
        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        let contentHostView = AccessoryContentHostView(
            contentView: contentView,
            position: .center,
            preferredSizeDidChange: { _ in }
        )
        let newOwner = UIView()
        newOwner.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = true

        contentHostView.detachContent(keepingSnapshot: false)

        #expect(contentView.superview === newOwner)
        #expect(contentView.translatesAutoresizingMaskIntoConstraints == true)
    }
}
