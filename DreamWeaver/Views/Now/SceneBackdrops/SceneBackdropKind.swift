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
    /// Painted coastal mist backdrop for「雾岸听潮」.
    case mistTide
    /// Painted deep-forest backdrop for「深林萤火」.
    case fireflies
    /// Painted night-sky bedroom backdrop for「星河远眠」.
    case starRiver
    /// Painted golden-field backdrop for「风过麦田」.
    case wheatWind
    /// Painted moonlit lake backdrop for「月夜静湖」.
    case moonLake
    /// Painted cozy-window backdrop for「暖灯陪伴」.
    case warmLamp
    /// Painted fireside backdrop for「炉边低语」.
    case fireplaceWhisper
    /// Painted porch-garden backdrop for「夏夜虫鸣」.
    case summerInsects
    /// Procedural Canvas motifs (snow, tide, …).
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
        case .mistTide:
            return .mistTide
        case .fireflies:
            return .fireflies
        case .starRiver:
            return .starRiver
        case .wheatWind:
            return .wheatWind
        case .moonLake:
            return .moonLake
        case .warmLamp:
            return .warmLamp
        case .fireplaceWhisper:
            return .fireplaceWhisper
        case .summerInsects:
            return .summerInsects
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
