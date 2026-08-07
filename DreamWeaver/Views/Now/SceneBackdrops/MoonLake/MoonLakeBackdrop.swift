import SwiftUI

/// Full-bleed still backdrop for「山色」.
struct MoonLakeBackdrop: View {
    var intensity: Double
    var isPlaying: Bool = true
    var reduceMotion: Bool = false

    var body: some View {
        PaintedCoverBackdrop(
            style: .moonLake,
            intensity: intensity,
            fallbackColors: [
                Color(hex: 0xAEB9C4),
                Color(hex: 0x287F93),
                Color(hex: 0x003544)
            ]
        )
    }
}

#Preview {
    MoonLakeBackdrop(intensity: 0.8, isPlaying: true)
}
