import SwiftUI

/// Full-bleed painted backdrop for「喜马拉雅」.
struct HimalayaBackdrop: View {
    var intensity: Double

    var body: some View {
        PaintedCoverBackdrop(
            style: .himalaya,
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
    HimalayaBackdrop(intensity: 0.8)
}
