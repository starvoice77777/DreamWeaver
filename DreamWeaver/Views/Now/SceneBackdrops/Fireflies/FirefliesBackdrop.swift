import SwiftUI

/// Full-bleed painted backdrop for「深林萤火」.
struct FirefliesBackdrop: View {
    var intensity: Double

    var body: some View {
        PaintedCoverBackdrop(
            style: .fireflies,
            intensity: intensity,
            fallbackColors: [
                Color(hex: 0x0B1A14),
                Color(hex: 0x163028),
                Color(hex: 0x0A1520)
            ]
        )
    }
}

#Preview {
    FirefliesBackdrop(intensity: 0.8)
}
