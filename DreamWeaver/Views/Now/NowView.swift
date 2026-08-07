import SwiftUI

struct NowView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var showTimerPicker = false
    @State private var showSceneLibrary = false
    @State private var swipeOffset: CGFloat = 0
    @State private var isSwipeSwitching = false
    @State private var stageWidth: CGFloat = 390
    /// Adjacent scenes in library order, preloaded so swipe commits never wait on I/O.
    @State private var leftNeighbor: DreamScene?
    @State private var rightNeighbor: DreamScene?

    private var reduceMotion: Bool {
        appState.reduceMotion || systemReduceMotion
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width

            ZStack {
                // Incoming scene peek (preloaded cover / palette) — short-video style.
                if swipeOffset < -1, let peek = rightNeighbor {
                    SceneSwipePeekBackdrop(scene: peek)
                        .offset(x: width + swipeOffset)
                        .allowsHitTesting(false)
                } else if swipeOffset > 1, let peek = leftNeighbor {
                    SceneSwipePeekBackdrop(scene: peek)
                        .offset(x: -width + swipeOffset)
                        .allowsHitTesting(false)
                }

                LinearGradient(
                    colors: [.black.opacity(0.25), .clear, .black.opacity(0.45)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .offset(x: swipeOffset * 0.55)
                .allowsHitTesting(false)

                // Tap blank area: dismiss overlays first, otherwise toggle controls.
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissOverlayOrToggleControls()
                    }
                    .accessibilityHint("点按空白处返回或显示隐藏控件；左右滑动按顺序切换场景")

                // Same opacity/scale fade as the tab bar (not insert/remove transition).
                SoundMixCircleEditor(showTimerPicker: $showTimerPicker)
                    .opacity(appState.controlsVisible ? 1 : 0)
                    .scaleEffect(appState.controlsVisible ? 1 : 0.98)
                    .allowsHitTesting(appState.controlsVisible)
                    .accessibilityHidden(!appState.controlsVisible)
                    .zIndex(1)

                VStack(spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        HStack(alignment: .top) {
                            NowTimerButton(showPicker: $showTimerPicker)

                            Spacer()

                            Button {
                                appState.bumpInteraction()
                                showTimerPicker = false
                                appState.closeMixPalette()
                                showSceneLibrary = true
                            } label: {
                                Image(systemName: "line.3.horizontal")
                                    .font(.system(size: DreamIconSize.primary, weight: .medium))
                                    .foregroundStyle(
                                        DreamTheme.componentAccent.opacity(0.92)
                                    )
                                    .frame(width: 44, height: 44)
                                    .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .animation(
                                .easeInOut(duration: 0.36),
                                value: appState.currentScene.palette
                            )
                            .accessibilityLabel("浏览全部场景")
                        }

                        if showTimerPicker {
                            NowTimerScale()
                                .frame(
                                    width: min(max(width - 152, 168), 228),
                                    height: 44
                                )
                                .offset(x: 52, y: 0)
                                .transition(
                                    .scale(scale: 0.88, anchor: .leading)
                                        .combined(with: .offset(x: -8))
                                        .combined(with: .opacity)
                                )
                                .zIndex(1)
                        }
                    }
                    .frame(height: 44, alignment: .top)
                    .padding(.leading, 20)
                    .padding(.trailing, 28)
                    .padding(.top, 18)
                    .animation(
                        .spring(response: 0.34, dampingFraction: 0.84),
                        value: showTimerPicker
                    )

                    Spacer()
                }
                .opacity(appState.controlsVisible ? 1 : 0)
                .allowsHitTesting(appState.controlsVisible)
                .zIndex(2)

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
            .frame(width: width, height: proxy.size.height)
            .onAppear { stageWidth = width }
            .onChange(of: width) { _, newWidth in
                stageWidth = newWidth
            }
        }
        .simultaneousGesture(sceneSwipeGesture)
        .animation(DreamTheme.chromeVisibilityAnimation, value: appState.controlsVisible)
        .fullScreenCover(isPresented: $showSceneLibrary) {
            SceneLibraryView(
                onSceneActivated: { scene in
                    showSceneLibrary = false
                    appState.enterDream(sceneId: scene.id)
                },
                onDismiss: {
                    showSceneLibrary = false
                }
            )
            .environmentObject(appState)
        }
        .onAppear {
            refillSwipeNeighbors()
        }
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
        .onChange(of: appState.isTransitioningScene) { _, transitioning in
            if !transitioning {
                swipeOffset = 0
                isSwipeSwitching = false
                refillSwipeNeighbors()
            }
        }
        .onChange(of: appState.currentSceneId) { _, _ in
            if !appState.isTransitioningScene, !isSwipeSwitching {
                refillSwipeNeighbors()
            }
        }
    }

    /// Short-video style: horizontal flick → seamless handoff into prefetched neighbor.
    private var sceneSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onChanged { value in
                guard canBeginSceneSwipe(value) else { return }
                swipeOffset = value.translation.width * (reduceMotion ? 0.22 : 0.42)
            }
            .onEnded { value in
                guard canBeginSceneSwipe(value) else {
                    settleSwipeOffset()
                    return
                }

                let dx = value.translation.width
                let predicted = value.predictedEndTranslation.width
                let horizontalEnough = abs(dx) > abs(value.translation.height) * 1.15
                let flicked = abs(dx) > 96 || abs(predicted) > 360

                if horizontalEnough && flicked {
                    commitPrefetchedSceneSwipe(direction: dx < 0 ? -1 : 1)
                } else {
                    settleSwipeOffset()
                }
            }
    }

    private func canBeginSceneSwipe(_ value: DragGesture.Value) -> Bool {
        guard !isSwipeSwitching else { return false }
        guard !appState.isTransitioningScene else { return false }
        guard !appState.userIsInteracting else { return false }
        guard !showTimerPicker, !appState.showMixPalette else { return false }
        return abs(value.translation.width) >= abs(value.translation.height) * 0.85
    }

    private func settleSwipeOffset() {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
            swipeOffset = 0
        }
    }

    private func commitPrefetchedSceneSwipe(direction: CGFloat) {
        let next: DreamScene?
        if direction < 0 {
            next = rightNeighbor
        } else {
            next = leftNeighbor
        }
        guard let next else {
            settleSwipeOffset()
            return
        }

        isSwipeSwitching = true
        let travel = stageWidth * direction
        let settle = reduceMotion ? 0.12 : 0.20

        withAnimation(.easeOut(duration: settle)) {
            // Align peek to full-bleed, then cut to live atmosphere without curtain.
            swipeOffset = travel
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(settle * 1_000_000_000))
            var cut = Transaction()
            cut.disablesAnimations = true
            withTransaction(cut) {
                appState.swipeIntoDream(sceneId: next.id)
                swipeOffset = 0
                isSwipeSwitching = false
            }
            refillSwipeNeighbors()
        }
    }

    private func refillSwipeNeighbors() {
        let scenes = appState.scenes
        guard scenes.count > 1,
              let currentIndex = scenes.firstIndex(where: { $0.id == appState.currentSceneId }) else {
            leftNeighbor = nil
            rightNeighbor = nil
            return
        }

        let previousIndex = currentIndex == scenes.startIndex
            ? scenes.index(before: scenes.endIndex)
            : scenes.index(before: currentIndex)
        let followingIndex = scenes.index(after: currentIndex)
        let nextIndex = followingIndex == scenes.endIndex
            ? scenes.startIndex
            : followingIndex

        let previous = scenes[previousIndex]
        let next = scenes[nextIndex]
        leftNeighbor = previous
        rightNeighbor = next

        appState.prefetchSwipeScene(previous.id)
        if next.id != previous.id {
            appState.prefetchSwipeScene(next.id)
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

/// Lightweight peek used during swipe — avoids spinning up a second full atmosphere stack.
private struct SceneSwipePeekBackdrop: View {
    let scene: DreamScene

    var body: some View {
        ZStack {
            scene.palette.gradient
            if let cover = SceneCoverArt.image(for: scene.visualStyle) {
                Image(uiImage: cover)
                    .resizable()
                    .scaledToFill()
            }
            LinearGradient(
                colors: [.black.opacity(0.22), .clear, .black.opacity(0.40)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .clipped()
        .ignoresSafeArea()
    }
}

struct SceneTitleOverlay: View {
    let name: String
    let subtitle: String
    var visible: Bool

    var body: some View {
        VStack(spacing: 10) {
            Text(name)
                .font(DreamTypography.dreamDisplay)
                .foregroundStyle(DreamTheme.moonWhite)
            Text(subtitle)
                .font(DreamTypography.body)
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
                        .font(.system(size: DreamIconSize.primary, weight: .medium))
                        .foregroundStyle(DreamTheme.componentAccent)
                        .frame(width: 56, height: 56)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .animation(
                    .easeInOut(duration: 0.36),
                    value: appState.currentScene.palette
                )
                .accessibilityLabel(appState.isPlaying ? "暂停" : "播放")

                PlaybackProgressSlider(value: $appState.playbackProgress) { isEditing in
                    if isEditing {
                        appState.userIsInteracting = true
                        appState.revealControls()
                    } else {
                        appState.bumpInteraction()
                    }
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
                        .font(.system(size: DreamIconSize.primary, weight: .medium))
                        .foregroundStyle(
                            appState.currentScene.isFavorite
                                ? DreamTheme.componentAccent
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

private struct PlaybackProgressSlider: View {
    @EnvironmentObject private var appState: AppState
    @Binding var value: Double
    var onEditingChanged: (Bool) -> Void

    @State private var isDragging = false

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let clampedValue = min(max(value, 0), 1)
            let fillWidth = width * clampedValue
            let waveformHeight: CGFloat = isDragging ? 26 : 22
            let waveformBarCount = max(15, min(42, Int(width / 5.8)))
            let waveformSlotWidth = width / CGFloat(waveformBarCount)
            let sceneAccent = DreamTheme.componentAccent
            let markWidth: CGFloat = isDragging ? 21 : 18
            let markHeight: CGFloat = isDragging ? 36 : 31
            // The logo's left edge tracks progress until its centre reaches
            // the waveform's right boundary; progress itself still reaches 100%.
            let markCenterX = min(
                max(fillWidth + markWidth / 2, markWidth / 2),
                width
            )

            ZStack {
                ForEach(0..<waveformBarCount, id: \.self) { index in
                    let barCenterX = waveformSlotWidth * (CGFloat(index) + 0.5)
                    let isPlayed = barCenterX <= fillWidth

                    Capsule()
                        .fill(
                            isPlayed
                                ? LinearGradient(
                                    colors: [
                                        sceneAccent.opacity(0.74),
                                        sceneAccent,
                                        sceneAccent.opacity(0.88)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                : LinearGradient(
                                    colors: [
                                        DreamTheme.moonWhite.opacity(isDragging ? 0.38 : 0.26),
                                        DreamTheme.moonWhite.opacity(isDragging ? 0.23 : 0.14)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                        )
                        .frame(
                            width: max(1.5, waveformSlotWidth * 0.42),
                            height: waveformHeight * waveformAmplitude(at: index)
                        )
                        .position(x: barCenterX, y: waveformHeight / 2)
                        .shadow(
                            color: isPlayed ? sceneAccent.opacity(isDragging ? 0.34 : 0.16) : .clear,
                            radius: isDragging ? 3 : 0
                        )
                }

                DreamWeaverProgressMark(
                    accent: sceneAccent,
                    isDragging: isDragging
                )
                .frame(width: markWidth, height: markHeight)
                .position(x: markCenterX, y: waveformHeight / 2)
                .accessibilityHidden(true)
            }
            .frame(width: width, height: waveformHeight)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: isDragging)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                            onEditingChanged(true)
                        }
                        value = min(max(gesture.location.x / width, 0), 1)
                    }
                    .onEnded { gesture in
                        value = min(max(gesture.location.x / width, 0), 1)
                        isDragging = false
                        onEditingChanged(false)
                    }
            )
        }
        .frame(height: 40)
        .accessibilityElement()
        .accessibilityLabel("场景进度")
        .accessibilityValue("\(Int(min(max(value, 0), 1) * 100))%")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                value = min(value + 0.05, 1)
            case .decrement:
                value = max(value - 0.05, 0)
            @unknown default:
                break
            }
            onEditingChanged(false)
        }
    }

    private func waveformAmplitude(at index: Int) -> CGFloat {
        let pattern: [CGFloat] = [
            0.44, 0.78, 0.37, 0.27, 0.55, 0.32, 0.92, 0.41,
            0.30, 0.68, 0.35, 0.26, 0.84, 0.48, 0.33, 0.58,
            0.88, 0.46, 0.29, 0.72, 0.40, 0.31, 0.62, 0.38
        ]
        return pattern[index % pattern.count]
    }
}

/// The progress position uses the same three-stroke DreamWeaver mark as the
/// launch screen, replacing a generic slider thumb with a branded waypoint.
private struct DreamWeaverProgressMark: View {
    let accent: Color
    let isDragging: Bool

    var body: some View {
        ZStack {
            ForEach(DreamWeaverMarkStroke.allCases) { stroke in
                DreamWeaverMarkPath(stroke: stroke)
                    .stroke(
                        LinearGradient(
                            colors: [
                                DreamTheme.moonWhite,
                                accent.opacity(0.96),
                                DreamTheme.moonWhite.opacity(0.92)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(
                            lineWidth: isDragging ? 1.7 : 1.45,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
            }
        }
        .shadow(
            color: accent.opacity(isDragging ? 0.34 : 0.22),
            radius: isDragging ? 2.5 : 1.5,
            y: 1
        )
        .scaleEffect(isDragging ? 1.08 : 1)
        .animation(.spring(response: 0.22, dampingFraction: 0.78), value: isDragging)
    }
}

struct NowTimerButton: View {
    @EnvironmentObject private var appState: AppState
    @Binding var showPicker: Bool

    var body: some View {
        Button {
            appState.bumpInteraction()
            withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                showPicker.toggle()
            }
        } label: {
            Image(systemName: "timer")
                .font(.system(size: DreamIconSize.primary, weight: .medium))
                .foregroundStyle(DreamTheme.componentAccent)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .animation(
            .easeInOut(duration: 0.36),
            value: appState.currentScene.palette
        )
        .accessibilityLabel("定时")
        .accessibilityValue("\(appState.sleepTimerDurationMinutes)分钟")
        .accessibilityHint("点按在右侧展开或收起计时刻度")
    }
}

private struct NowTimerScale: View {
    @EnvironmentObject private var appState: AppState
    @State private var previewMinutes: Int?

    private let minimumMinutes = 5
    private let maximumMinutes = 120
    private let minuteStep = 5
    private let tickMinutes = Array(stride(from: 10, through: 110, by: 10))
    private let labeledMinutes = [30, 60, 90]
    private let trackHeight: CGFloat = 42

    private var displayedMinutes: Int {
        previewMinutes ?? appState.sleepTimerDurationMinutes
    }

    private var remainingMinutes: Double {
        if let previewMinutes {
            return Double(previewMinutes)
        }
        return Double(appState.sleepTimerDurationMinutes)
            * (1 - min(max(appState.timerElapsedProgress, 0), 1))
    }

    var body: some View {
        GeometryReader { geometry in
            let trackWidth = max(geometry.size.width, 1)
            let progress = scaleProgress(for: remainingMinutes)
            let sceneAccent = DreamTheme.componentAccent

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                sceneAccent.opacity(0.18),
                                Color(hex: 0x0A101C).opacity(0.94)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                sceneAccent.opacity(0.96),
                                sceneAccent.opacity(0.72)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: trackWidth * progress)
                    .animation(.linear(duration: 0.24), value: progress)

                ForEach(tickMinutes, id: \.self) { minutes in
                    let labeled = labeledMinutes.contains(minutes)
                    Capsule(style: .continuous)
                        .fill(DreamTheme.moonWhite.opacity(labeled ? 0.34 : 0.20))
                        .frame(width: 1.25, height: labeled ? 13 : 7)
                        .position(
                            x: trackWidth * scaleProgress(for: Double(minutes)),
                            y: trackHeight / 2
                        )
                }

                Capsule(style: .continuous)
                    .fill(DreamTheme.moonWhite.opacity(0.96))
                    .frame(width: 2.5, height: trackHeight - 8)
                    .shadow(color: .black.opacity(0.22), radius: 2, x: 1)
                    .position(
                        x: trackWidth * progress,
                        y: trackHeight / 2
                    )
                    .opacity(progress > 0 ? 1 : 0)
                    .animation(.linear(duration: 0.24), value: progress)

                ForEach(labeledMinutes, id: \.self) { minutes in
                    Text("\(minutes)")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(DreamTheme.moonWhite.opacity(0.76))
                        .frame(width: 24, height: 24)
                        .background {
                            Circle()
                                .fill(Color.black.opacity(0.22))
                        }
                        .position(
                            x: trackWidth * scaleProgress(for: Double(minutes)),
                            y: trackHeight / 2
                        )
                }
            }
            .frame(width: trackWidth, height: trackHeight)
            .clipShape(Capsule(style: .continuous))
            .shadow(color: .black.opacity(0.28), radius: 12, y: 5)
            .contentShape(Capsule(style: .continuous))
            .gesture(
                durationDragGesture(
                    width: trackWidth,
                    leadingInset: 0
                )
            )
            .position(
                x: geometry.size.width / 2,
                y: geometry.size.height / 2
            )
        }
        .sensoryFeedback(.selection, trigger: displayedMinutes)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("计时时长刻度")
        .accessibilityValue("\(displayedMinutes)分钟")
    }

    private func scaleProgress(for minutes: Double) -> CGFloat {
        let clamped = min(max(minutes, 0), Double(maximumMinutes))
        return CGFloat(clamped / Double(maximumMinutes))
    }

    private func durationDragGesture(
        width: CGFloat,
        leadingInset: CGFloat
    ) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                previewMinutes = minutes(
                    at: value.location.x - leadingInset,
                    width: width
                )
            }
            .onEnded { value in
                let minutes = minutes(
                    at: value.location.x - leadingInset,
                    width: width
                )
                appState.setSleepTimerDuration(minutes: minutes)
                appState.bumpInteraction()
                previewMinutes = nil
            }
    }

    private func minutes(at x: CGFloat, width: CGFloat) -> Int {
        let progress = min(max(x / max(width, 1), 0), 1)
        let rawMinutes = Double(progress) * Double(maximumMinutes)
        let stepped = Int((rawMinutes / Double(minuteStep)).rounded()) * minuteStep
        return min(max(stepped, minimumMinutes), maximumMinutes)
    }
}

#Preview {
    NowView()
        .environmentObject(AppState())
}
