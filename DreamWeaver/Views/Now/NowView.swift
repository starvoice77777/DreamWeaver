import SwiftUI

struct NowView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var showTimerPicker = false

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

            // Tap blank area: dismiss overlays first, otherwise toggle controls.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissOverlayOrToggleControls()
                }
                .accessibilityHint("点按空白处返回或显示隐藏控件")

            // Same opacity/scale fade as the tab bar (not insert/remove transition).
            SoundMixCircleEditor(showTimerPicker: $showTimerPicker)
                .opacity(appState.controlsVisible ? 1 : 0)
                .scaleEffect(appState.controlsVisible ? 1 : 0.98)
                .allowsHitTesting(appState.controlsVisible)
                .accessibilityHidden(!appState.controlsVisible)
                .zIndex(1)

            VStack {
                SectionHeader(title: "此刻")
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .opacity(appState.controlsVisible ? 1 : 0)
                    .scaleEffect(appState.controlsVisible ? 1 : 0.98)
                    .allowsHitTesting(false)

                SceneTitleOverlay(
                    name: appState.currentScene.name,
                    subtitle: appState.currentScene.subtitle,
                    visible: appState.sceneTitleVisible
                )
                .padding(.top, appState.controlsVisible ? 8 : 72)
                .allowsHitTesting(false)

                Spacer(minLength: 0)
                    .allowsHitTesting(false)
            }
            .allowsHitTesting(false)
        }
        .animation(DreamTheme.chromeVisibilityAnimation, value: appState.controlsVisible)
        .onChange(of: appState.controlsVisible) { _, visible in
            if !visible {
                showTimerPicker = false
            }
        }
        .onChange(of: appState.showMixPalette) { _, showing in
            if showing {
                showTimerPicker = false
            }
        }
    }

    private func dismissOverlayOrToggleControls() {
        if showTimerPicker {
            withAnimation(DreamTheme.chromeVisibilityAnimation) { showTimerPicker = false }
        } else if appState.showMixPalette {
            appState.closeMixPalette()
        } else {
            appState.toggleControlsVisibility()
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
    @Binding var showTimerPicker: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
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

            NowTimerButton(showPicker: $showTimerPicker)

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
            .onTapGesture {
                appState.bumpInteraction()
            }

            Button {
                appState.bumpInteraction()
                appState.toggleFavorite(sceneId: appState.currentSceneId)
            } label: {
                Image(systemName: appState.currentScene.isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(
                        appState.currentScene.isFavorite
                            ? DreamTheme.warmApricot
                            : DreamTheme.moonWhite.opacity(0.75)
                    )
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(appState.currentScene.isFavorite ? "取消收藏" : "收藏")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }
}

struct NowTimerButton: View {
    @EnvironmentObject private var appState: AppState
    @Binding var showPicker: Bool

    var body: some View {
        Button {
            appState.bumpInteraction()
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "timer")
                    .font(.system(size: 16, weight: .medium))
                Text(appState.timerOption.shortLabel)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(DreamTheme.moonWhite)
            .frame(width: 56, height: 56)
            .background {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.12))

                    if appState.timerOption.showsCountdownFill {
                        Circle()
                            .trim(from: 0, to: max(appState.timerElapsedProgress, 0.001))
                            .stroke(
                                DreamTheme.warmApricot.opacity(0.85),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .padding(2)
                            .animation(.linear(duration: 0.25), value: appState.timerElapsedProgress)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.4)
                .onEnded { _ in
                    appState.bumpInteraction()
                    withAnimation(.easeInOut(duration: 0.35)) {
                        showPicker = true
                    }
                }
        )
        .accessibilityLabel("定时，当前\(appState.timerOption.rawValue)")
        .accessibilityHint("长按选择定时时长")
    }
}

struct NowTimerPickerPopup: View {
    @EnvironmentObject private var appState: AppState
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("定时")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DreamTheme.secondaryText)
                .padding(.horizontal, 4)

            ForEach(appState.showDemoControls ? TimerOption.demoCases : TimerOption.userFacingCases) { option in
                TimerOptionChip(
                    option: option,
                    selected: appState.timerOption == option,
                    progress: appState.timerOption == option ? appState.timerElapsedProgress : 0
                ) {
                    appState.setTimerOption(option)
                    appState.bumpInteraction()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isPresented = false
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(14)
        .frame(width: 148)
        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
        .accessibilityLabel("选择定时时长")
    }
}

#Preview {
    NowView()
        .environmentObject(AppState())
}
