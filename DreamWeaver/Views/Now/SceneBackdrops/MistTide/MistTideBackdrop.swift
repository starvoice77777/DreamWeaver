import SwiftUI

/// Full-bleed painted backdrop for「雾岸听潮」.
struct MistTideBackdrop: View {
    var intensity: Double

    var body: some View {
        PaintedCoverBackdrop(
            style: .mistTide,
            intensity: intensity,
            fallbackColors: [
                Color(hex: 0x1A2533),
                Color(hex: 0x3A4E63),
                Color(hex: 0x1C2430)
            ]
        )
    }
}

#Preview {
    MistTideBackdrop(intensity: 0.8)
}
