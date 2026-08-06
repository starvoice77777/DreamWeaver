import SwiftUI

/// Full-bleed looping backdrop for「月夜静湖」.
struct MoonLakeBackdrop: View {
    var intensity: Double
    var isPlaying: Bool = true
    var reduceMotion: Bool = false

    @StateObject private var videoPlayer = LoopingVideoPlayer(
        resourceName: "moon_lake_bg",
        fileExtension: "mp4",
        subdirectory: "Scenes/MoonLake",
        loopOverlap: 0.25
    )

    var body: some View {
        PaintedCoverBackdrop(
            style: .moonLake,
            intensity: intensity,
            fallbackColors: [
                Color(hex: 0x10182A),
                Color(hex: 0x243552),
                Color(hex: 0x0C1018)
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
                        Color.black.opacity(0.14),
                        Color.clear,
                        Color(hex: 0x07101E).opacity(0.32 + 0.10 * (1 - intensity))
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
    MoonLakeBackdrop(intensity: 0.8, isPlaying: true)
}
