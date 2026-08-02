import Foundation

/// Reserved bridge for future sleep-sound pairing (rain / tide / fire / ambient).
/// No audio is played yet — safe to call from UI without side effects.
@MainActor
final class FluidSceneAudioManager {
    static let shared = FluidSceneAudioManager()

    private(set) var activeSceneType: FluidSceneType?

    private init() {}

    func playSceneSound(sceneType: FluidSceneType) {
        activeSceneType = sceneType
        // Future: map cloud → rain/ambient mist, water → tide, flame → fireplace.
    }

    func stop() {
        activeSceneType = nil
    }
}
