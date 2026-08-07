import SwiftUI

/// Full-bleed painted backdrop for「长路」.
struct LongRoadBackdrop: View {
    var intensity: Double

    var body: some View {
        PaintedCoverBackdrop(
            style: .longRoad,
            intensity: intensity,
            fallbackColors: [
                Color(hex: 0x2A1E16),
                Color(hex: 0x4A3424),
                Color(hex: 0x18120E)
            ]
        )
    }
}

#Preview {
    LongRoadBackdrop(intensity: 0.8)
}
