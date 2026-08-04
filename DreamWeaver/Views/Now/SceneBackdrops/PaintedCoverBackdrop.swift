import SwiftUI

/// Static full-bleed cover art for painted single-image scenes.
/// No breathing scale or particle overlays — image + readability veil only.
struct PaintedCoverBackdrop: View {
    let style: SceneVisualStyle
    var intensity: Double = 1
    var fallbackColors: [Color]

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                if let image = SceneCoverArt.image(for: style) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size.width, height: size.height)
                        .clipped()
                } else {
                    LinearGradient(
                        colors: fallbackColors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.28),
                        Color.clear,
                        Color.black.opacity(0.38 + 0.12 * (1 - intensity))
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
    }
}
