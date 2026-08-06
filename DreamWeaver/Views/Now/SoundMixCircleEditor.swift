import SwiftUI

/// Read-only spatial-position stage for the Now tab.
struct SoundMixCircleEditor: View {
    @EnvironmentObject private var appState: AppState
    @Binding var showTimerPicker: Bool

    /// Disk rings appear briefly as each scene enters, then recede behind the nodes.
    @State private var diskVisible = false
    @State private var hideDiskTask: Task<Void, Never>?
    /// Waiting to show the scene-enter intro once the stage is actually visible.
    @State private var pendingSceneIntro = false
    /// Cold launch needs a short delay so ContentView fade-in finishes first.
    @State private var sceneIntroAfterLaunch = false
    @State private var sceneIntroTask: Task<Void, Never>?

    /// Upper golden-section point for the disk center.
    private let goldenFromTop: CGFloat = 0.382
    /// Dock center sits at 75% of the screen height.
    private let dockFromTop: CGFloat = 0.75
    private let maxDisk: CGFloat = 392
    private let dockHeight: CGFloat = 108
    private let diskFadeDuration: TimeInterval = 0.35
    /// Boot / enter-scene intro hold (not the drag idle delay).
    private let sceneIntroHold: TimeInterval = 2.0
    /// Let the launch overlay finish dissolving before counting the scene intro.
    private let launchRevealDelay: TimeInterval = 0.18
    private var activeSources: [SoundSource] {
        appState.currentScene.soundSources.filter(\.isEnabled)
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let side = min(size.width - 16, maxDisk)
            let localCircleSize = CGSize(width: side, height: side)
            let center = CGPoint(x: size.width / 2, y: size.height * goldenFromTop)
            let origin = CGPoint(x: center.x - side / 2, y: center.y - side / 2)
            let dockCenter = CGPoint(
                x: size.width / 2,
                y: size.height * dockFromTop
            )
            let dockWidth = min(size.width, side + 48)

            ZStack {
                circleRings(size: localCircleSize)
                    .frame(width: side, height: side)
                    .position(center)
                    .opacity(diskVisible ? 1 : 0)
                    .animation(.easeInOut(duration: diskFadeDuration), value: diskVisible)
                    .allowsHitTesting(false)

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
            .onAppear {
                requestSceneIntroDisk(afterLaunch: appState.showLaunch)
            }
            .onChange(of: appState.currentSceneId) { _, _ in
                if appState.consumeSkipSceneChromeIntro() { return }
                requestSceneIntroDisk(afterLaunch: false)
            }
            .onChange(of: appState.showLaunch) { _, launching in
                if !launching {
                    requestSceneIntroDisk(afterLaunch: true)
                }
            }
            .onChange(of: appState.isTransitioningScene) { _, transitioning in
                if !transitioning {
                    tryPlayPendingSceneIntro()
                }
            }
            .onChange(of: appState.controlsVisible) { _, visible in
                if visible {
                    tryPlayPendingSceneIntro()
                }
            }
            .onChange(of: appState.selectedTab) { _, tab in
                if tab == .now {
                    tryPlayPendingSceneIntro()
                }
            }
        }
        .animation(.easeInOut(duration: 0.35), value: showTimerPicker)
        .accessibilityHint("圆盘仅展示当前场景中各音源的空间位置")
    }

    private func listenerAnchor(at center: CGPoint) -> some View {
        Image(systemName: "person.fill")
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(DreamTheme.moonWhite.opacity(0.88))
            .frame(width: 44, height: 44)
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

    // MARK: - Layers

    private func circleRings(size: CGSize) -> some View {
        let side = min(size.width, size.height)
        return ZStack {
            Circle()
                .stroke(DreamTheme.chromeStroke, lineWidth: 2)
                .frame(width: side * 0.92, height: side * 0.92)

            Circle()
                .stroke(Color.white.opacity(0.07), lineWidth: 1.5)
                .frame(width: side * 0.58, height: side * 0.58)
        }
        .frame(width: size.width, height: size.height)
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
            name: source.name,
            gain: SpatialMixMapping.gain(for: source.position.radius)
        )
        .position(home)
        .accessibilityLabel("\(source.name)，空间位置展示")
        .accessibilityHint("播放时不可调整位置")
    }

    private func nodeChrome(symbol: String, name: String, gain: Double) -> some View {
        let scale = 0.78 + gain * 0.5
        let iconSize: CGFloat = 14 * scale
        let side: CGFloat = 50 * scale
        let textOpacity = 0.55 + gain * 0.4

        return VStack(spacing: 2) {
            Image(systemName: symbol)
                .font(.system(size: iconSize))
            Text(name)
                .font(.system(size: 9))
                .lineLimit(1)
        }
        .foregroundStyle(DreamTheme.moonWhite.opacity(textOpacity))
        .frame(width: side, height: side)
        .dreamSpatialLiquidGlassCircle(
            accent: appState.currentScene.palette.accentColor,
            intensity: 0.55 + gain * 0.45,
            interactive: false
        )
    }

    // MARK: - Disk visibility & effects

    /// Queue a short scene intro; plays only when launch / transition / controls allow it.
    private func requestSceneIntroDisk(afterLaunch: Bool) {
        pendingSceneIntro = true
        if afterLaunch {
            sceneIntroAfterLaunch = true
        }
        tryPlayPendingSceneIntro()
    }

    private func tryPlayPendingSceneIntro() {
        guard pendingSceneIntro else { return }
        guard !appState.showLaunch else { return }
        guard !appState.isTransitioningScene else { return }
        guard appState.controlsVisible else { return }
        guard appState.selectedTab == .now else { return }

        pendingSceneIntro = false
        let delay = sceneIntroAfterLaunch ? launchRevealDelay : 0
        sceneIntroAfterLaunch = false

        sceneIntroTask?.cancel()
        hideDiskTask?.cancel()
        sceneIntroTask = Task {
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard appState.selectedTab == .now,
                      appState.controlsVisible,
                      !appState.showLaunch,
                      !appState.isTransitioningScene
                else {
                    pendingSceneIntro = true
                    return
                }
                withAnimation(.easeInOut(duration: diskFadeDuration)) {
                    diskVisible = true
                }
                scheduleDiskHide(after: sceneIntroHold)
            }
        }
    }

    private func scheduleDiskHide(after delay: TimeInterval) {
        hideDiskTask?.cancel()
        hideDiskTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: diskFadeDuration)) {
                    diskVisible = false
                }
            }
        }
    }

}

#Preview {
    ZStack {
        DreamTheme.deepBlue.ignoresSafeArea()
        SoundMixCircleEditor(showTimerPicker: .constant(false))
    }
    .environmentObject(AppState())
}
