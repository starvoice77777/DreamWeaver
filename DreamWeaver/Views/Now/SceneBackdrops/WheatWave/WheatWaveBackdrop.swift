import SwiftUI

/// Full-bleed still backdrop for「麦浪」.
struct WheatWaveBackdrop: View {
    var intensity: Double
    var isPlaying: Bool = true
    var reduceMotion: Bool = false

    var body: some View {
        PaintedCoverBackdrop(
            style: .wheatWave,
            intensity: intensity,
            fallbackColors: [
                Color(hex: 0x1C2418),
                Color(hex: 0x3A4630),
                Color(hex: 0x141810)
            ]
        )
    }
}

#Preview {
    WheatWaveBackdrop(intensity: 0.8, isPlaying: true)
}
