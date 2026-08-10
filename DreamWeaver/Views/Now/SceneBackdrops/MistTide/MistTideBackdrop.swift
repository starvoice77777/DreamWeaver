import SwiftUI

/// Full-bleed, silent looping video backdrop for「星期天」.
struct MistTideBackdrop: View {
    var intensity: Double
    var isPlaying: Bool
    var reduceMotion: Bool

    var body: some View {
        BundledVideoSceneBackdrop(
            style: .mistTide,
            resourceName: "mist_tide_bg",
            resourceSubdirectory: "Scenes/MistTide",
            isActive: isPlaying && !reduceMotion,
            intensity: intensity,
            fallbackColors: [
                Color(hex: 0x72AAB8),
                Color(hex: 0x1688A0),
                Color(hex: 0x0A5063)
            ]
        )
    }
}

#Preview {
    MistTideBackdrop(
        intensity: 0.8,
        isPlaying: true,
        reduceMotion: false
    )
}
