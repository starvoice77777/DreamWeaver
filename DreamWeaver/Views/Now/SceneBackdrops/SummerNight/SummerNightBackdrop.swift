import SwiftUI

/// Full-bleed painted backdrop for「夏夜」.
struct SummerNightBackdrop: View {
    var intensity: Double

    var body: some View {
        PaintedCoverBackdrop(
            style: .summerNight,
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
    SummerNightBackdrop(intensity: 0.8)
}
