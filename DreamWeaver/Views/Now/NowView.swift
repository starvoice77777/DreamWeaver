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
                SceneTitleOverlay(
                    name: appState.currentScene.name,
                    subtitle: appState.currentScene.subtitle,
                    visible: appState.sceneTitleVisible
                )
                .padding(.top, appState.controlsVisible ? 16 : 72)
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
        GlassEffectContainer(spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                Button {
                    appState.bumpInteraction()
                    appState.togglePlayback()
                } label: {
                    Image(systemName: appState.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(DreamTheme.moonWhite)
                        .frame(width: 56, height: 56)
                        .dreamSpatialLiquidGlassCircle(
                            accent: appState.currentScene.palette.accentColor,
                            intensity: appState.isPlaying ? 0.92 : 0.68
                        )
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
}

struct NowTimerButton: View {
    @EnvironmentObject private var appState: AppState
    @Binding var showPicker: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            if showPicker {
                NowTimerPickerPopup(isPresented: $showPicker)
                    .padding(.bottom, 56 + 14)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.92, anchor: .bottom)),
                            removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .bottom))
                        )
                    )
                    .zIndex(1)
            }

            Button {
                appState.bumpInteraction()
                withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                    showPicker.toggle()
                }
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
                .dreamSpatialLiquidGlassCircle(
                    accent: DreamTheme.warmApricot,
                    intensity: showPicker ? 1.0 : 0.82
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("定时，当前\(appState.timerOption.rawValue)")
            .accessibilityHint("点按选择定时时长")
            .zIndex(2)
        }
        // Layout stays button-sized; peapod draws upward without joining the button.
        .frame(width: 78, height: 56, alignment: .bottom)
    }
}

/// Peapod column of timer options that grows upward from the timer button.
/// The five choices form one continuous capsule; the current button stays separate below.
struct NowTimerPickerPopup: View {
    @EnvironmentObject private var appState: AppState
    @Binding var isPresented: Bool
    @State private var draggedIndex: Int?

    private let podWidth: CGFloat = 86
    private let rowHeight: CGFloat = 42
    /// Clearance between the outer peapod stroke and inner content / selection.
    private let podPadding: CGFloat = 5
    private let selectInsetX: CGFloat = 5
    private let selectInsetY: CGFloat = 4

    private var podOptions: [TimerOption] {
        TimerOption.userFacingCases
    }

    private var selectedIndex: Int {
        podOptions.firstIndex(of: appState.timerOption) ?? 0
    }

    private var visibleSelectionIndex: Int {
        draggedIndex ?? selectedIndex
    }

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: rowHeight / 2, style: .continuous)
                .fill(DreamTheme.moonWhite.opacity(0.09))
                .overlay {
                    RoundedRectangle(cornerRadius: rowHeight / 2, style: .continuous)
                        .strokeBorder(DreamTheme.moonWhite.opacity(0.72), lineWidth: 1)
                }
                .frame(height: rowHeight - selectInsetY * 2)
                .padding(.horizontal, selectInsetX)
                .scaleEffect(x: 1.04, y: 1.06)
                .offset(
                    y: CGFloat(visibleSelectionIndex) * rowHeight + selectInsetY
                )
                .shadow(color: DreamTheme.warmApricot.opacity(0.16), radius: 8)
                .animation(
                    .spring(response: 0.28, dampingFraction: 0.76),
                    value: visibleSelectionIndex
                )
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                ForEach(Array(podOptions.enumerated()), id: \.element.id) { index, option in
                    podRow(option, index: index)
                }
            }
        }
        .padding(podPadding)
        .frame(width: podWidth)
        .contentShape(Capsule(style: .continuous))
        .dreamRefractiveLiquidGlassCapsule(
            accent: DreamTheme.warmApricot,
            intensity: 0.90
        )
        .highPriorityGesture(selectionDragGesture)
        .sensoryFeedback(.selection, trigger: visibleSelectionIndex)
        .accessibilityLabel("选择定时时长")
    }

    private func podRow(_ option: TimerOption, index: Int) -> some View {
        let selected = appState.timerOption == option
        let highlighted = visibleSelectionIndex == index

        return Button {
            commitSelection(at: index)
        } label: {
            Text(option.rawValue)
                .font(.system(size: 12, weight: highlighted ? .semibold : .regular))
                .foregroundStyle(
                    highlighted
                        ? DreamTheme.moonWhite
                        : DreamTheme.moonWhite.opacity(0.66)
                )
                .frame(maxWidth: .infinity)
                .frame(height: rowHeight)
                .scaleEffect(highlighted ? 1.12 : 1)
                .animation(
                    .spring(response: 0.25, dampingFraction: 0.72),
                    value: highlighted
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.rawValue)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var selectionDragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                let index = optionIndex(at: value.location.y)
                guard draggedIndex != index else { return }
                withAnimation(.spring(response: 0.22, dampingFraction: 0.78)) {
                    draggedIndex = index
                }
            }
            .onEnded { value in
                commitSelection(at: draggedIndex ?? optionIndex(at: value.location.y))
            }
    }

    private func optionIndex(at y: CGFloat) -> Int {
        let rawIndex = Int(floor((y - podPadding) / rowHeight))
        return min(max(rawIndex, 0), podOptions.count - 1)
    }

    private func commitSelection(at index: Int) {
        guard podOptions.indices.contains(index) else { return }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.76)) {
            draggedIndex = index
            appState.setTimerOption(podOptions[index])
        }
        appState.bumpInteraction()

        Task {
            try? await Task.sleep(for: .milliseconds(140))
            await MainActor.run {
                draggedIndex = nil
                withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                    isPresented = false
                }
            }
        }
    }
}

#Preview {
    NowView()
        .environmentObject(AppState())
}
