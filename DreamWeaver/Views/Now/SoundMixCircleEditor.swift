import SwiftUI
import UIKit

/// Read-only spatial-position stage for the Now tab.
struct SoundMixCircleEditor: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Binding var showTimerPicker: Bool

    /// Dock center sits at 75% of the screen height.
    private let dockFromTop: CGFloat = 0.75
    private let dockHeight: CGFloat = 108

    private var reduceMotion: Bool {
        appState.reduceMotion || systemReduceMotion
    }
    private var activeSources: [SoundSource] {
        appState.currentScene.soundSources.filter(\.isEnabled)
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let side = SpatialDiskLayout.diameter(in: size)
            let localCircleSize = CGSize(width: side, height: side)
            let center = SpatialDiskLayout.center(in: size)
            let origin = CGPoint(x: center.x - side / 2, y: center.y - side / 2)
            let dockCenter = CGPoint(
                x: size.width / 2,
                y: size.height * dockFromTop
            )
            let dockWidth = min(size.width, side + 48)

            ZStack {
                BreathingSpatialRings(
                    accent: DreamTheme.componentAccent,
                    reduceMotion: reduceMotion
                )
                    .frame(width: side, height: side)
                    .position(center)

                GlassEffectContainer(spacing: 18) {
                    ZStack {
                        ForEach(activeSources) { source in
                            sourceNode(
                                source,
                                circleSize: localCircleSize,
                                circleOrigin: origin
                            )
                            .allowsHitTesting(false)
                            .zIndex(2)
                        }

                        listenerAnchor(at: center)
                            .zIndex(3)
                    }
                    .frame(width: size.width, height: size.height)
                }
                .frame(width: size.width, height: size.height)

                bottomDock(width: dockWidth)
                    .frame(width: dockWidth, height: dockHeight)
                    .position(dockCenter)
                    .zIndex(4)

            }
            .frame(width: size.width, height: size.height)
        }
        .animation(.easeInOut(duration: 0.35), value: showTimerPicker)
        .accessibilityHint("圆盘仅展示当前场景中各音源的空间位置")
    }

    private func listenerAnchor(at center: CGPoint) -> some View {
        DreamWeaverListenerMark(
            accent: DreamTheme.componentAccent,
            lineWidth: 2
        )
            .frame(width: 20.7, height: 35.7)
            .frame(width: 52, height: 52)
            .dreamSpatialLiquidGlassCircle(
                accent: DreamTheme.warmApricot,
                intensity: 0.92,
                interactive: false
            )
        .position(center)
        .allowsHitTesting(false)
        .accessibilityLabel("聆听位置")
        .accessibilityHint("当前仅展示空间位置")
    }

    private func bottomDock(width: CGFloat) -> some View {
        NowControlsOverlay(showTimerPicker: $showTimerPicker)
            .frame(width: width, height: dockHeight)
    }

    // MARK: - Nodes

    private func sourceNode(
        _ source: SoundSource,
        circleSize: CGSize,
        circleOrigin: CGPoint
    ) -> some View {
        let local = source.position.point(in: circleSize)
        let home = CGPoint(x: circleOrigin.x + local.x, y: circleOrigin.y + local.y)

        return nodeChrome(
            symbol: source.symbolName,
            gain: SpatialMixMapping.gain(for: source.position.radius)
        )
        .position(home)
        .accessibilityLabel("\(source.name)，空间位置展示")
        .accessibilityHint("播放时不可调整位置")
    }

    private func nodeChrome(symbol: String, gain: Double) -> some View {
        let scale = 0.78 + gain * 0.5
        let iconSize: CGFloat = DreamIconSize.secondary * scale
        let side: CGFloat = 58 * scale
        let iconOpacity = 0.40 + gain * 0.30

        let candidate = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedSymbol = !candidate.isEmpty && UIImage(systemName: candidate) != nil
            ? candidate
            : "waveform"

        return Image(systemName: resolvedSymbol)
            .font(.system(size: iconSize))
            .foregroundStyle(DreamTheme.moonWhite.opacity(iconOpacity))
            .frame(width: side, height: side)
            .dreamSpatialLiquidGlassCircle(
                accent: DreamTheme.componentAccent,
                intensity: 0.55 + gain * 0.45,
                interactive: false
            )
    }

}

#Preview {
    ZStack {
        DreamTheme.deepBlue.ignoresSafeArea()
        SoundMixCircleEditor(showTimerPicker: .constant(false))
    }
    .environmentObject(AppState())
}
