import CoreGraphics
import Foundation

/// Declares how a scene paints its full-bleed backdrop.
/// Keep Canvas motifs for lightweight scenes; use layered UIViews when a scene
/// needs custom art stacks, masks, or future audio-reactive motion.
enum SceneBackdropKind: Equatable {
    /// 5-layer Chinese rainy-night stack (images + rain + warm lamp).
    case rainyNight(RainyNightConfiguration)
    /// Immersive emotional fluid color space.
    case emotionalFluid
    /// Procedural Canvas motifs (fireflies, snow, tide, …).
    case canvasMotif
}

extension SceneVisualStyle {
    /// Per-style backdrop strategy. Swap individual cases as art/interaction lands.
    var backdropKind: SceneBackdropKind {
        switch self {
        case .rainEaves:
            return .rainyNight(.rainEaves)
        case .emotionalFluid:
            return .emotionalFluid
        default:
            return .canvasMotif
        }
    }
}

/// Shared hooks for scene backdrops that can react to playback / audio later.
@MainActor
protocol SceneBackdropAnimating: AnyObject {
    func setActive(_ active: Bool)
    func setReduceMotion(_ reduce: Bool)
    func setIntensity(_ intensity: CGFloat)
    /// Optional: 0…1 audio envelope for future interactive scenes.
    func applyAudioLevel(_ level: CGFloat)
}

extension SceneBackdropAnimating {
    func applyAudioLevel(_ level: CGFloat) {}
}
