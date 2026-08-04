import SwiftUI

/// Full-bleed painted backdrop for「暖灯陪伴」.
struct WarmLampBackdrop: View {
    var intensity: Double

    var body: some View {
        PaintedCoverBackdrop(
            style: .warmLamp,
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
    WarmLampBackdrop(intensity: 0.8)
}
