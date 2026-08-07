import SwiftUI

private struct SceneAdaptivePaletteKey: EnvironmentKey {
    static let defaultValue = ScenePalette(
        top: 0x1A2740,
        mid: 0x2C3E55,
        bottom: 0x101621,
        accent: 0xD79A72
    )
}

extension EnvironmentValues {
    var sceneAdaptivePalette: ScenePalette {
        get { self[SceneAdaptivePaletteKey.self] }
        set { self[SceneAdaptivePaletteKey.self] = newValue }
    }

    /// Controls use one restrained neutral tone across every scene.
    var sceneAdaptiveAccent: Color {
        DreamTheme.componentAccent
    }
}

/// Darkened scene colors keep secondary pages legible while preserving the
/// atmosphere of the currently selected scene on the Now tab.
struct SceneAdaptiveBackground: View {
    let palette: ScenePalette

    var body: some View {
        ZStack {
            Color.black

            palette.gradient
                .opacity(0.74)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.12),
                    Color.black.opacity(0.30),
                    Color.black.opacity(0.56)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    palette.accentColor.opacity(0.14),
                    Color.clear
                ],
                center: UnitPoint(x: 0.78, y: 0.08),
                startRadius: 0,
                endRadius: 300
            )
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.45), value: palette)
    }
}
