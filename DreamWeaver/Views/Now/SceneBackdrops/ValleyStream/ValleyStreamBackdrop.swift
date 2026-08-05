import SwiftUI

/// Full-bleed painted backdrop for「幽谷清流」.
struct ValleyStreamBackdrop: View {
    var intensity: Double

    var body: some View {
        PaintedCoverBackdrop(
            style: .valleyStream,
            intensity: intensity,
            fallbackColors: [
                Color(hex: 0x13241F),
                Color(hex: 0x1F3D38),
                Color(hex: 0x101820)
            ]
        )
    }
}

#Preview {
    ValleyStreamBackdrop(intensity: 0.8)
}
