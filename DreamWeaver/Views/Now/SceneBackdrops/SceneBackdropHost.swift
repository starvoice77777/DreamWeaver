import SwiftUI

/// Routes each scene to its custom backdrop implementation.
/// Prefer adding a new layered UIView for art-heavy / interactive scenes;
/// keep `SceneAtmosphereCanvas` for lightweight procedural motifs.
struct SceneBackdropHost: View {
    let scene: DreamScene
    var isPlaying: Bool
    var reduceMotion: Bool
    var intensity: Double
    var depthMotionEnabled: Bool

    var body: some View {
        SceneDepthMotionContainer(
            isEnabled: depthMotionEnabled,
            maximumOffset: depthOffset
        ) {
            backdrop
        }
        .ignoresSafeArea()
        // Avoid crossfade “refresh” when identity swaps mid-swipe; curtain path hides the cut.
    }

    @ViewBuilder
    private var backdrop: some View {
        Group {
            switch scene.visualStyle.backdropKind {
            case .rainyNight(let configuration):
                RainyNightBackdrop(
                    configuration: configuration,
                    isPlaying: isPlaying,
                    reduceMotion: reduceMotion,
                    intensity: intensity
                )
            case .emotionalFluid:
                EmotionalFluidView(
                    initialSceneType: .cloud,
                    isPlaying: isPlaying,
                    reduceMotion: reduceMotion
                )
            case .mistTide:
                MistTideBackdrop(intensity: intensity)
            case .valleyStream:
                ValleyStreamBackdrop(intensity: intensity)
            case .snowStudy:
                SnowStudyBackdrop(intensity: intensity)
            case .flight:
                FlightBackdrop(intensity: intensity)
            case .hairCare:
                HairCareBackdrop(intensity: intensity)
            case .himalaya:
                HimalayaBackdrop(intensity: intensity)
            case .starRiver:
                StarRiverBackdrop(intensity: intensity)
            case .wheatWave:
                WheatWaveBackdrop(
                    intensity: intensity,
                    isPlaying: isPlaying,
                    reduceMotion: reduceMotion
                )
            case .moonLake:
                MoonLakeBackdrop(
                    intensity: intensity,
                    isPlaying: isPlaying,
                    reduceMotion: reduceMotion
                )
            case .longRoad:
                LongRoadBackdrop(intensity: intensity)
            case .fireplaceWhisper:
                FireplaceWhisperBackdrop(intensity: intensity)
            case .summerNight:
                SummerNightBackdrop(intensity: intensity)
            case .alpsCableCar:
                BundledVideoSceneBackdrop(
                    style: .alpsCableCar,
                    resourceName: "alps_cable_car",
                    resourceSubdirectory: "Scenes/Alps",
                    isActive: isPlaying && !reduceMotion,
                    intensity: intensity,
                    fallbackColors: [
                        Color(hex: 0xD7DDD8),
                        Color(hex: 0xA8B5B6),
                        Color(hex: 0x273533)
                    ]
                )
            case .twilight:
                BundledVideoSceneBackdrop(
                    style: .twilight,
                    resourceName: "twilight_bg",
                    resourceSubdirectory: "Scenes/Twilight",
                    isActive: isPlaying && !reduceMotion,
                    intensity: intensity,
                    fallbackColors: [
                        Color(hex: 0x3A294A),
                        Color(hex: 0xA96F5D),
                        Color(hex: 0x12131C)
                    ]
                )
            case .prelude:
                PaintedCoverBackdrop(
                    style: .prelude,
                    intensity: intensity,
                    fallbackColors: [
                        Color(hex: 0x51484A),
                        Color(hex: 0xA57562),
                        Color(hex: 0xD77A3B)
                    ]
                )
            case .ornateArchitecture:
                PaintedCoverBackdrop(
                    style: .ornateArchitecture,
                    intensity: intensity,
                    fallbackColors: [
                        Color(hex: 0xB6B6B6),
                        Color(hex: 0x676767),
                        Color(hex: 0x151515)
                    ]
                )
            case .canvasMotif:
                SceneAtmosphereCanvas(
                    scene: scene,
                    isPlaying: isPlaying,
                    reduceMotion: reduceMotion,
                    intensity: intensity
                )
            }
        }
        .ignoresSafeArea()
    }

    private var depthOffset: CGFloat {
        // Keep the effect ambient: the listener sees a scene respond to tilt,
        // not a foreground card floating over the UI.
        CGFloat(7 + 9 * min(max(intensity, 0.2), 1))
    }
}
