import SwiftUI

/// Full-bleed looping footage with a matching bundled poster underneath.
/// The poster keeps scene cards, swipe previews, and the first decode frame
/// visually consistent while AVPlayer prepares the video.
struct BundledVideoSceneBackdrop: View {
    let style: SceneVisualStyle
    let isActive: Bool
    let intensity: Double
    let fallbackColors: [Color]

    @StateObject private var video: LoopingVideoPlayer

    init(
        style: SceneVisualStyle,
        resourceName: String,
        resourceSubdirectory: String,
        isActive: Bool,
        intensity: Double,
        fallbackColors: [Color]
    ) {
        self.style = style
        self.isActive = isActive
        self.intensity = intensity
        self.fallbackColors = fallbackColors
        _video = StateObject(
            wrappedValue: LoopingVideoPlayer(
                resourceName: resourceName,
                fileExtension: "mp4",
                subdirectory: resourceSubdirectory
            )
        )
    }

    var body: some View {
        ZStack {
            PaintedCoverBackdrop(
                style: style,
                intensity: intensity,
                fallbackColors: fallbackColors
            )

            if video.isAvailable {
                LoopingVideoBackdrop(player: video.player)
                    .ignoresSafeArea()
            }

            LinearGradient(
                colors: [
                    Color.black.opacity(0.28),
                    Color.clear,
                    Color.black.opacity(0.42)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        .onAppear(perform: updatePlayback)
        .onChange(of: isActive) { _, _ in updatePlayback() }
        .onDisappear { video.pause() }
    }

    private func updatePlayback() {
        if isActive {
            video.play()
        } else {
            video.pause()
        }
    }
}
