import SwiftUI

/// Full-bleed painted backdrop for「月夜静湖」.
struct MoonLakeBackdrop: View {
    var intensity: Double

    var body: some View {
        PaintedCoverBackdrop(
            style: .moonLake,
            intensity: intensity,
            fallbackColors: [
                Color(hex: 0x10182A),
                Color(hex: 0x243552),
                Color(hex: 0x0C1018)
            ]
        )
    }
}

#Preview {
    MoonLakeBackdrop(intensity: 0.8)
}
