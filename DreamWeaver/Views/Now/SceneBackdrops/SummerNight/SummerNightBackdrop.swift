import SwiftUI

/// Full-bleed, silent looping video backdrop for「夏夜」.
struct SummerNightBackdrop: View {
    var intensity: Double
    var isPlaying: Bool
    var reduceMotion: Bool

    var body: some View {
        BundledVideoSceneBackdrop(
            style: .summerNight,
            resourceName: "summer_night_bg",
            resourceSubdirectory: "Scenes/SummerNight",
            isActive: isPlaying && !reduceMotion,
            intensity: intensity,
            fallbackColors: [
                Color(hex: 0x142018),
                Color(hex: 0x243828),
                Color(hex: 0x101410)
            ]
        )
    }
}

#Preview {
    SummerNightBackdrop(
        intensity: 0.8,
        isPlaying: true,
        reduceMotion: false
    )
}
