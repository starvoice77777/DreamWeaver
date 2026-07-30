import SwiftUI

struct NowView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private var reduceMotion: Bool {
        appState.reduceMotion || systemReduceMotion
    }

    var body: some View {
        ZStack {
            SceneAtmosphereView(
                scene: appState.currentScene,
                isPlaying: appState.isPlaying,
                reduceMotion: reduceMotion,
                intensity: appState.animationIntensity
            )
            .opacity(appState.isTransitioningScene ? 0.15 : 1)
            .animation(.easeInOut(duration: reduceMotion ? 0.2 : 0.8), value: appState.isTransitioningScene)
            .animation(.easeInOut(duration: 0.8), value: appState.currentSceneId)

            LinearGradient(
                colors: [.black.opacity(0.25), .clear, .black.opacity(0.45)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // Tap blank area to show / hide controls;
            // long-press blank area to open scene detail.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { appState.toggleControlsVisibility() }
                .onLongPressGesture(minimumDuration: 0.55) {
                    appState.openSceneDetail()
                }
                .accessibilityHint("点按显示或隐藏控件，长按打开场景详情")

            VStack {
                if appState.controlsVisible {
                    SectionHeader(title: "此刻")
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }

                SceneTitleOverlay(
                    name: appState.currentScene.name,
                    subtitle: appState.currentScene.subtitle,
                    visible: appState.sceneTitleVisible
                )
                .padding(.top, appState.controlsVisible ? 24 : 72)
                .allowsHitTesting(false)

                Spacer()
                    .allowsHitTesting(false)

                if appState.controlsVisible {
                    NowControlsOverlay()
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .padding(.bottom, 100)
                }
            }
            .allowsHitTesting(appState.controlsVisible)
            .animation(.easeInOut(duration: 0.45), value: appState.controlsVisible)
        }
        .sheet(isPresented: Binding(
            get: { appState.showSceneDetail },
            set: { if !$0 { appState.closeSceneDetail() } else { appState.showSceneDetail = true } }
        )) {
            SceneDetailSheet()
                .environmentObject(appState)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
    }
}

struct SceneTitleOverlay: View {
    let name: String
    let subtitle: String
    var visible: Bool

    var body: some View {
        VStack(spacing: 10) {
            Text(name)
                .font(.system(size: 34, weight: .ultraLight))
                .foregroundStyle(DreamTheme.moonWhite)
            Text(subtitle)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(DreamTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
        }
        .opacity(visible ? 1 : 0)
        .allowsHitTesting(false)
    }
}

struct NowControlsOverlay: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 22) {
            Button {
                appState.bumpInteraction()
                appState.togglePlayback()
            } label: {
                Image(systemName: appState.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(DreamTheme.moonWhite)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(appState.isPlaying ? "暂停" : "播放")

            Button {
                appState.openSceneDetail()
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(appState.currentScene.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(DreamTheme.moonWhite)
                    HStack(spacing: 8) {
                        Text(appState.timerOption.rawValue)
                        Text("·")
                        Text(appState.isPlaying ? "播放中" : "已暂停")
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(DreamTheme.secondaryText)

                    ProgressView(value: appState.playbackProgress)
                        .tint(DreamTheme.warmApricot.opacity(0.85))
                        .accessibilityLabel("模拟播放进度")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("打开场景详情")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .dreamGlass(cornerRadius: 24)
        .padding(.horizontal, 24)
    }
}

#Preview {
    NowView()
        .environmentObject(AppState())
}
