import SwiftUI

/// Full-bleed painted backdrop for「炉边低语」.
struct FireplaceWhisperBackdrop: View {
    var intensity: Double

    var body: some View {
        PaintedCoverBackdrop(
            style: .fireplaceWhisper,
            intensity: intensity,
            fallbackColors: [
                Color(hex: 0x241810),
                Color(hex: 0x4A2C1A),
                Color(hex: 0x140E0A)
            ]
        )
    }
}

#Preview {
    FireplaceWhisperBackdrop(intensity: 0.8)
}
