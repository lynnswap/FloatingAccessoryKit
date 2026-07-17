import Testing
import UIKit
@testable import FloatingAccessoryKit

@MainActor
@Suite
struct TabBarAccessoryContentMeasurementTests {
    @Test func standardControlsRetainTheirSuggestedRelativeWidths() {
        let imageButton = UIButton(type: .system)
        var imageConfiguration = UIButton.Configuration.plain()
        imageConfiguration.image = UIImage(systemName: "plus")
        imageButton.configuration = imageConfiguration

        let menuButton = UIButton(type: .system)
        var menuConfiguration = UIButton.Configuration.plain()
        menuConfiguration.title = "Actions"
        menuButton.configuration = menuConfiguration
        menuButton.menu = UIMenu(
            children: [
                UIAction(title: "First") { _ in }
            ]
        )
        menuButton.showsMenuAsPrimaryAction = true

        let proposedHeight: CGFloat = 42
        let imageWidth = TabBarAccessoryContentMeasurement.width(
            for: imageButton,
            proposedHeight: proposedHeight,
            policy: .proposedHeight
        )
        let menuWidth = TabBarAccessoryContentMeasurement.width(
            for: menuButton,
            proposedHeight: proposedHeight,
            policy: .proposedHeight
        )

        #expect(imageWidth > 0)
        #expect(menuWidth > imageWidth)
    }

    @Test func squareImageButtonsScaleFromProposedHeight() {
        let stackView = UIStackView(arrangedSubviews: [makeImageButton("plus")])
        let proposedHeight: CGFloat = 42
        let initialWidth = TabBarAccessoryContentMeasurement.width(
            for: stackView,
            proposedHeight: proposedHeight,
            policy: .proposedHeight
        )

        stackView.insertArrangedSubview(makeImageButton("minus"), at: 0)
        let updatedWidth = TabBarAccessoryContentMeasurement.width(
            for: stackView,
            proposedHeight: proposedHeight,
            policy: .proposedHeight
        )

        #expect(abs(initialWidth - proposedHeight) <= 0.5)
        #expect(abs(updatedWidth - proposedHeight * 2) <= 0.5)
    }

    private func makeImageButton(_ systemName: String) -> UIButton {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: systemName)
        button.configuration = configuration
        button.widthAnchor.constraint(equalTo: button.heightAnchor).isActive = true
        return button
    }
}
