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
        .animation(.easeInOut(duration: 0.35), value: scene.id)
    }
}
