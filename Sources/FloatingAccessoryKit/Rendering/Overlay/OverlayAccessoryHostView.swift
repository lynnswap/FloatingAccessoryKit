import UIKit

@MainActor
final class OverlayAccessoryHostView: UIView {
    private let visualEffectView: UIVisualEffectView
    private let backgroundColorView = UIView()

    init(effect: UIBlurEffect, color: UIColor?) {
        visualEffectView = UIVisualEffectView(effect: effect)

        super.init(frame: .zero)

        backgroundColor = .clear
        clipsToBounds = true
        layer.cornerCurve = .continuous

        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.isUserInteractionEnabled = false
        addSubview(visualEffectView)

        backgroundColorView.translatesAutoresizingMaskIntoConstraints = false
        backgroundColorView.isUserInteractionEnabled = false
        backgroundColorView.backgroundColor = color
        addSubview(backgroundColorView)

        NSLayoutConstraint.activate([
            visualEffectView.topAnchor.constraint(equalTo: topAnchor),
            visualEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: bottomAnchor),
            backgroundColorView.topAnchor.constraint(equalTo: topAnchor),
            backgroundColorView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundColorView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundColorView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }

    func updateBackground(effect: UIBlurEffect, color: UIColor?) {
        visualEffectView.effect = effect
        backgroundColorView.backgroundColor = color
    }
}
