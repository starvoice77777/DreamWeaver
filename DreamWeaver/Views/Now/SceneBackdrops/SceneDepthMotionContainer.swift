import SwiftUI
import UIKit

/// Adds a subtle device-tilt parallax to a full-bleed scene backdrop.
///
/// The hosted content is oversized before applying UIKit's motion effect so
/// the background can move without revealing an edge. This keeps controls in
/// the foreground stationary while the scene gains a gentle sense of depth.
struct SceneDepthMotionContainer<Content: View>: UIViewControllerRepresentable {
    let content: Content
    let isEnabled: Bool
    let maximumOffset: CGFloat

    init(
        isEnabled: Bool,
        maximumOffset: CGFloat,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.isEnabled = isEnabled
        self.maximumOffset = maximumOffset
    }

    func makeUIViewController(context: Context) -> SceneDepthMotionViewController<Content> {
        SceneDepthMotionViewController(
            rootView: content,
            isEnabled: isEnabled,
            maximumOffset: maximumOffset
        )
    }

    func updateUIViewController(
        _ controller: SceneDepthMotionViewController<Content>,
        context: Context
    ) {
        controller.update(
            rootView: content,
            isEnabled: isEnabled,
            maximumOffset: maximumOffset
        )
    }
}

final class SceneDepthMotionViewController<Content: View>: UIViewController {
    private let hostingController: UIHostingController<Content>
    private var edgeConstraints: [NSLayoutConstraint] = []
    private var isMotionEnabled = false
    private var appliedMaximumOffset: CGFloat = 0

    init(rootView: Content, isEnabled: Bool, maximumOffset: CGFloat) {
        hostingController = UIHostingController(rootView: rootView)
        super.init(nibName: nil, bundle: nil)
        isMotionEnabled = isEnabled
        appliedMaximumOffset = maximumOffset
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .clear
        view.clipsToBounds = true

        let hostedView = hostingController.view!
        hostedView.backgroundColor = .clear
        hostedView.translatesAutoresizingMaskIntoConstraints = false

        addChild(hostingController)
        view.addSubview(hostedView)
        edgeConstraints = [
            hostedView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostedView.topAnchor.constraint(equalTo: view.topAnchor),
            hostedView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ]
        NSLayoutConstraint.activate(edgeConstraints)
        hostingController.didMove(toParent: self)

        applyDepthEffect()
    }

    func update(rootView: Content, isEnabled: Bool, maximumOffset: CGFloat) {
        hostingController.rootView = rootView
        let wasEnabled = isMotionEnabled
        let previousOffset = appliedMaximumOffset
        isMotionEnabled = isEnabled
        appliedMaximumOffset = maximumOffset

        guard isViewLoaded,
              wasEnabled != isEnabled || abs(previousOffset - maximumOffset) > 0.1
        else { return }

        applyDepthEffect()
    }

    private func applyDepthEffect() {
        let offset = isMotionEnabled ? max(appliedMaximumOffset, 0) : 0
        let overscan = offset + 6
        edgeConstraints[0].constant = -overscan
        edgeConstraints[1].constant = overscan
        edgeConstraints[2].constant = -overscan
        edgeConstraints[3].constant = overscan

        let hostedView = hostingController.view!
        hostedView.motionEffects = []
        guard offset > 0 else { return }

        let horizontal = UIInterpolatingMotionEffect(
            keyPath: "center.x",
            type: .tiltAlongHorizontalAxis
        )
        horizontal.minimumRelativeValue = -offset
        horizontal.maximumRelativeValue = offset

        let vertical = UIInterpolatingMotionEffect(
            keyPath: "center.y",
            type: .tiltAlongVerticalAxis
        )
        vertical.minimumRelativeValue = -offset
        vertical.maximumRelativeValue = offset

        let group = UIMotionEffectGroup()
        group.motionEffects = [horizontal, vertical]
        hostedView.addMotionEffect(group)
    }
}
