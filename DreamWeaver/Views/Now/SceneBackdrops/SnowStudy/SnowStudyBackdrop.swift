import SwiftUI

/// Full-bleed painted backdrop for「雪夜书房」.
struct SnowStudyBackdrop: View {
    var intensity: Double

    var body: some View {
        PaintedCoverBackdrop(
            style: .snowStudy,
            intensity: intensity,
            fallbackColors: [
                Color(hex: 0x17243A),
                Color(hex: 0x3A4555),
                Color(hex: 0x111725)
            ]
        )
    }
}

#Preview {
    SnowStudyBackdrop(intensity: 0.8)
}
