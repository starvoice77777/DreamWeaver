import SwiftUI

/// Full-bleed looping backdrop for「风过麦田」.
struct WheatWindBackdrop: View {
    var intensity: Double
    var isPlaying: Bool = true
    var reduceMotion: Bool = false

    @StateObject private var videoPlayer = LoopingVideoPlayer(
        resourceName: "wheat_wind_bg",
        fileExtension: "mp4",
        subdirectory: "Scenes/WheatWind"
    )

    var body: some View {
        PaintedCoverBackdrop(
            style: .wheatWind,
            intensity: intensity,
            fallbackColors: [
                Color(hex: 0x1C2418),
                Color(hex: 0x3A4630),
                Color(hex: 0x141810)
            ]
        )
        .overlay {
            if videoPlayer.isAvailable {
                LoopingVideoBackdrop(player: videoPlayer.player)
                    .clipped()
            }
        }
        .onAppear(perform: updatePlayback)
        .onDisappear {
            videoPlayer.pause()
        }
        .onChange(of: isPlaying) { _, _ in
            updatePlayback()
        }
        .onChange(of: reduceMotion) { _, _ in
            updatePlayback()
        }
        .overlay {
            if videoPlayer.isAvailable {
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.28),
                        Color.clear,
                        Color.black.opacity(0.38 + 0.12 * (1 - intensity))
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
        }
    }

    private func updatePlayback() {
        if isPlaying && !reduceMotion {
            videoPlayer.play()
        } else {
            videoPlayer.pause()
        }
    }
}

#Preview {
    WheatWindBackdrop(intensity: 0.8, isPlaying: true)
}
