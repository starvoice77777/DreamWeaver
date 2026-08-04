import SwiftUI

/// Full-bleed painted backdrop for「夏夜虫鸣」.
struct SummerInsectsBackdrop: View {
    var intensity: Double

    var body: some View {
        PaintedCoverBackdrop(
            style: .summerInsects,
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
    SummerInsectsBackdrop(intensity: 0.8)
}
