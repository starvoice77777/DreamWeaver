import SwiftUI

/// Routes each scene to its custom backdrop implementation.
/// Prefer adding a new layered UIView for art-heavy / interactive scenes;
/// keep `SceneAtmosphereCanvas` for lightweight procedural motifs.
struct SceneBackdropHost: View {
    let scene: DreamScene
    var isPlaying: Bool
    var reduceMotion: Bool
    var intensity: Double

    var body: some View {
        SceneDepthMotionContainer(
            isEnabled: !reduceMotion,
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
            case .cloudBreath:
                CloudBreathBackdrop(intensity: intensity)
            case .hairCare:
                HairCareBackdrop(intensity: intensity)
            case .fireflies:
                FirefliesBackdrop(intensity: intensity)
            case .starRiver:
                StarRiverBackdrop(intensity: intensity)
            case .wheatWind:
                WheatWindBackdrop(
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
            case .warmLamp:
                WarmLampBackdrop(intensity: intensity)
            case .fireplaceWhisper:
                FireplaceWhisperBackdrop(intensity: intensity)
            case .summerInsects:
                SummerInsectsBackdrop(intensity: intensity)
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
