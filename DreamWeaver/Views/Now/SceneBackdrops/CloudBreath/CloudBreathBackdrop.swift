import SwiftUI

/// Full-bleed painted backdrop for「云间呼吸」.
struct CloudBreathBackdrop: View {
    var intensity: Double

    var body: some View {
        PaintedCoverBackdrop(
            style: .cloudBreath,
            intensity: intensity,
            fallbackColors: [
                Color(hex: 0x263A68),
                Color(hex: 0x7186B2),
                Color(hex: 0x17274A)
            ]
        )
    }
}

#Preview {
    CloudBreathBackdrop(intensity: 0.8)
}
