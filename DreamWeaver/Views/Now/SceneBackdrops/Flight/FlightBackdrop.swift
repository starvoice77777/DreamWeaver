import SwiftUI

/// Full-bleed painted backdrop for「飞行」.
struct FlightBackdrop: View {
    var intensity: Double

    var body: some View {
        PaintedCoverBackdrop(
            style: .flight,
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
    FlightBackdrop(intensity: 0.8)
}
