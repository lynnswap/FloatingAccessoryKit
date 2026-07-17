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
            preferredSizeDidChange: { _ in }
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
            preferredSizeDidChange: { _ in }
        )
        contentHostView.frame = CGRect(x: 0, y: 0, width: 96, height: 48)

        contentHostView.layoutIfNeeded()

        #expect(contentView.bounds.size == CGSize(width: 84, height: 42))
        #expect(contentView.center == CGPoint(x: 48, y: 24))
    }

    @Test func preferredSizeChangesAnimateAfterInitialMeasurement() {
        let contentView = MutableSizeView(
            size: CGSize(width: 84, height: 42)
        )
        var animationRequests: [Bool] = []
        let contentHostView = AccessoryContentHostView(
            contentView: contentView
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

    @Test func internalConstraintChangeInvalidatesPreferredSizeAutomatically() async {
        let contentView = UIView()
        let width = contentView.widthAnchor.constraint(equalToConstant: 84)
        NSLayoutConstraint.activate([
            width,
            contentView.heightAnchor.constraint(equalToConstant: 42)
        ])
        var animationRequests: [Bool] = []
        var preferredSizeContinuation: CheckedContinuation<Void, Never>?
        let contentHostView = AccessoryContentHostView(
            contentView: contentView
        ) { animated in
            animationRequests.append(animated)
            if animationRequests.count == 2 {
                preferredSizeContinuation?.resume()
                preferredSizeContinuation = nil
            }
        }
        contentHostView.frame = CGRect(x: 0, y: 0, width: 96, height: 48)
        let rootViewController = UIViewController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = rootViewController
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        rootViewController.view.addSubview(contentHostView)

        contentHostView.layoutIfNeeded()
        await withCheckedContinuation { continuation in
            preferredSizeContinuation = continuation
            width.constant = 126
        }

        #expect(animationRequests == [false, true])
    }

    @Test func deinitializationRestoresConsumerAutoresizing() {
        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = true
        weak var weakContentHostView: AccessoryContentHostView?

        do {
            let contentHostView = AccessoryContentHostView(
                contentView: contentView,
                preferredSizeDidChange: { _ in }
            )
            weakContentHostView = contentHostView
            #expect(contentView.translatesAutoresizingMaskIntoConstraints == false)
        }

        #expect(weakContentHostView == nil)
        #expect(contentView.translatesAutoresizingMaskIntoConstraints == true)
    }

    @Test func detachingReparentedContentRestoresConsumerAutoresizing() {
        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = true
        let contentHostView = AccessoryContentHostView(
            contentView: contentView,
            preferredSizeDidChange: { _ in }
        )
        let newOwner = UIView()
        newOwner.addSubview(contentView)

        contentHostView.detachContent(keepingSnapshot: false)

        #expect(contentView.superview === newOwner)
        #expect(contentView.translatesAutoresizingMaskIntoConstraints == true)
    }

    @Test func deinitializationRestoresReparentedConsumerAutoresizing() {
        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = true
        let newOwner = UIView()
        weak var weakContentHostView: AccessoryContentHostView?

        do {
            let contentHostView = AccessoryContentHostView(
                contentView: contentView,
                preferredSizeDidChange: { _ in }
            )
            weakContentHostView = contentHostView
            newOwner.addSubview(contentView)
        }

        #expect(weakContentHostView == nil)
        #expect(contentView.superview === newOwner)
        #expect(contentView.translatesAutoresizingMaskIntoConstraints == true)
    }

    @Test func detachingReparentedContentPreservesNewOwnerAutoresizingChange() {
        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        let contentHostView = AccessoryContentHostView(
            contentView: contentView,
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
