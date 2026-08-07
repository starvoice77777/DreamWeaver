import SwiftUI

/// Full-bleed painted backdrop for「星期天」.
struct MistTideBackdrop: View {
    var intensity: Double

    var body: some View {
        PaintedCoverBackdrop(
            style: .mistTide,
            intensity: intensity,
            fallbackColors: [
                Color(hex: 0x72AAB8),
                Color(hex: 0x1688A0),
                Color(hex: 0x0A5063)
            ]
        )
    }
}

#Preview {
    MistTideBackdrop(intensity: 0.8)
}
