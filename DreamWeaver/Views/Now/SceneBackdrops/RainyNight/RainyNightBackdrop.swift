import SwiftUI

/// SwiftUI host for `RainyNightView`.
struct RainyNightBackdrop: UIViewRepresentable {
    var configuration: RainyNightConfiguration = .rainEaves
    var isPlaying: Bool
    var reduceMotion: Bool
    var intensity: Double
    var lampDesignPoint: CGPoint?

    func makeUIView(context: Context) -> RainyNightView {
        let view = RainyNightView(configuration: configuration)
        context.coordinator.view = view
        apply(to: view)
        return view
    }

    func updateUIView(_ uiView: RainyNightView, context: Context) {
        context.coordinator.view = uiView
        if context.coordinator.lastConfiguration != configuration {
            uiView.updateConfiguration(configuration)
            context.coordinator.lastConfiguration = configuration
        }
        apply(to: uiView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func apply(to view: RainyNightView) {
        view.setActive(isPlaying)
        view.setReduceMotion(reduceMotion)
        view.setIntensity(CGFloat(intensity))
        if let lampDesignPoint {
            view.updateLampPosition(lampDesignPoint)
        }
    }

    final class Coordinator {
        var view: RainyNightView?
        var lastConfiguration: RainyNightConfiguration?
    }
}
