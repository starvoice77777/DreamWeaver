import SwiftUI

/// Full-bleed painted backdrop for「风过麦田」.
struct WheatWindBackdrop: View {
    var intensity: Double

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
    }
}

#Preview {
    WheatWindBackdrop(intensity: 0.8)
}
