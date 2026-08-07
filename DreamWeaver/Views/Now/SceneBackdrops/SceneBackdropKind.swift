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
    /// Painted seaside Sunday backdrop for「星期天」.
    case mistTide
    /// Painted forest-stream backdrop for「幽谷清流」.
    case valleyStream
    /// Painted snowy study backdrop for「雪夜书房」.
    case snowStudy
    /// Painted sunset-flight backdrop for「飞行」.
    case flight
    /// Painted home-spa backdrop for「洗头陪伴」.
    case hairCare
    /// Painted mountain backdrop for「喜马拉雅」.
    case himalaya
    /// Painted night-sky bedroom backdrop for「星河远眠」.
    case starRiver
    /// Painted golden-field backdrop for「麦浪」.
    case wheatWave
    /// Painted mountain-and-lake backdrop for「山色」.
    case moonLake
    /// Painted long-road backdrop for「长路」.
    case longRoad
    /// Painted fireside backdrop for「炉边低语」.
    case fireplaceWhisper
    /// Painted forest-night backdrop for「夏夜」.
    case summerNight
    /// Looping alpine cable-car footage for「阿尔卑斯」.
    case alpsCableCar
    /// Looping dusk footage for「黄昏」.
    case twilight
    /// Still cinematic opening frame for「序幕」.
    case prelude
    /// Still monochrome architectural frame for「雕梁画栋」.
    case ornateArchitecture
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
        case .valleyStream:
            return .valleyStream
        case .snowStudy:
            return .snowStudy
        case .flight:
            return .flight
        case .hairCare:
            return .hairCare
        case .himalaya:
            return .himalaya
        case .starRiver:
            return .starRiver
        case .wheatWave:
            return .wheatWave
        case .moonLake:
            return .moonLake
        case .longRoad:
            return .longRoad
        case .fireplaceWhisper:
            return .fireplaceWhisper
        case .summerNight:
            return .summerNight
        case .alpsCableCar:
            return .alpsCableCar
        case .twilight:
            return .twilight
        case .prelude:
            return .prelude
        case .ornateArchitecture:
            return .ornateArchitecture
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
