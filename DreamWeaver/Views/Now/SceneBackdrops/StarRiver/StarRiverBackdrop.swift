import SwiftUI

/// Full-bleed painted backdrop for「星河远眠」.
struct StarRiverBackdrop: View {
    var intensity: Double

    var body: some View {
        PaintedCoverBackdrop(
            style: .starRiver,
            intensity: intensity,
            fallbackColors: [
                Color(hex: 0x090B18),
                Color(hex: 0x1A1F3A),
                Color(hex: 0x0A0C16)
            ]
        )
    }
}

#Preview {
    StarRiverBackdrop(intensity: 0.8)
}
