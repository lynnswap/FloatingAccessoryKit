import SwiftUI
import UIKit

@MainActor
@available(iOS 26.0, *)
public final class TabBarAccessoryController {
    public enum Position: Sendable {
        case leading
        case center
        case trailing
    }

    private weak var tabBarController: UITabBarController?
    private let coordinator = TabBarAccessoryCoordinator()

    public init(tabBarController: UITabBarController) {
        self.tabBarController = tabBarController
        TabBarAccessoryViewLifecycleHooks.register(coordinator, for: tabBarController)
    }

    public var isHidden: Bool {
        coordinator.isHidden
    }

    public func setContent(
        _ view: UIView?,
        position: Position = .trailing,
        animated: Bool = false
    ) {
        guard let tabBarController else {
            return
        }

        coordinator.setAccessoryView(
            view,
            position: position,
            animated: animated,
            in: tabBarController,
            hostingController: nil
        )
    }

    public func setContent<Content: SwiftUI.View>(
        position: Position = .trailing,
        animated: Bool = false,
        @SwiftUI.ViewBuilder _ content: @escaping () -> Content
    ) {
        guard let tabBarController else {
            return
        }

        let hostingController = UIHostingController(
            rootView: TabBarAccessorySwiftUIRoot(content: content)
        )
        hostingController.sizingOptions = [.intrinsicContentSize]
        hostingController.view.backgroundColor = UIColor.clear

        coordinator.setAccessoryView(
            hostingController.view,
            position: position,
            animated: animated,
            in: tabBarController,
            hostingController: hostingController
        )
    }

    public func setHidden(
        _ hidden: Bool,
        animated: Bool = false
    ) {
        guard let tabBarController else {
            return
        }

        coordinator.setHidden(
            hidden,
            animated: animated,
            in: tabBarController
        )
    }
}

#if DEBUG
#Preview("UIView") {
    PreviewTabBarController { tabBarController in
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "plus"), for: .normal)

        tabBarController.accessoryController.setContent(button)
    }
}

#Preview("SwiftUI") {
    PreviewTabBarController { tabBarController in
        tabBarController.accessoryController.setContent {
            Button {} label: {
                Image(systemName: "plus")
            }
        }
    }
}

@MainActor
@available(iOS 26.0, *)
private final class PreviewTabBarController: UITabBarController {
    lazy var accessoryController = TabBarAccessoryController(tabBarController: self)
    private let configureAccessory: (PreviewTabBarController) -> Void

    init(configureAccessory: @escaping (PreviewTabBarController) -> Void) {
        self.configureAccessory = configureAccessory
        super.init(nibName: nil, bundle: nil)
        self.tabBarMinimizeBehavior = .onScrollDown
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        viewControllers = [
            makePreviewTab(title: "Home", systemImageName: "house"),
            makePreviewTab(title: "Settings", systemImageName: "gearshape")
        ]
        updateAccessory()
    }

    func updateAccessory() {
        configureAccessory(self)
    }

    private func makePreviewTab(title: String, systemImageName: String) -> UIViewController {
        let viewController = UIHostingController(rootView: PreviewScrollView())
        viewController.title = title
        viewController.tabBarItem = UITabBarItem(
            title: title,
            image: UIImage(systemName: systemImageName),
            selectedImage: nil
        )
        return viewController
    }
}

private struct PreviewScrollView: View {
    var body: some View {
        GeometryReader { reader in
            let height = reader.size.height * 0.6
            ScrollView {
                Rectangle()
                    .fill(.black)
                    .frame(height: height)
                Rectangle()
                    .fill(.mint.opacity(0.1))
                    .frame(height: height)
                Rectangle()
                    .fill(.black)
                    .frame(height: height)
            }
        }
    }
}
#endif
