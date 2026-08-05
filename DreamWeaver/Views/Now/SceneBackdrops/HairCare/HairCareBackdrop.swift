import SwiftUI

/// Full-bleed painted backdrop for「洗头陪伴」.
struct HairCareBackdrop: View {
    var intensity: Double

    var body: some View {
        PaintedCoverBackdrop(
            style: .hairCare,
            intensity: intensity,
            fallbackColors: [
                Color(hex: 0x171B22),
                Color(hex: 0x59422C),
                Color(hex: 0x0C1119)
            ]
        )
    }
}

#Preview {
    HairCareBackdrop(intensity: 0.8)
}
