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

                SceneAtmosphereView(
                    scene: appState.currentScene,
                    isPlaying: appState.isPlaying,
                    reduceMotion: reduceMotion,
                    intensity: appState.animationIntensity
                )
                .offset(x: swipeOffset)
                .opacity(appState.isTransitioningScene ? 0.15 : 1)
                .animation(.easeInOut(duration: reduceMotion ? 0.2 : 0.8), value: appState.isTransitioningScene)

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

                VStack {
                    HStack {
                        Spacer()
                        Button {
                            appState.bumpInteraction()
                            showTimerPicker = false
                            appState.closeMixPalette()
                            showSceneLibrary = true
                        } label: {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(DreamTheme.moonWhite.opacity(0.82))
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(Color.black.opacity(0.16)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("浏览全部场景")
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
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
                        .font(DreamTypography.cardTitle)
                        .foregroundStyle(DreamTheme.moonWhite)

                    PlaybackProgressSlider(value: $appState.playbackProgress) { isEditing in
                        if isEditing {
                            appState.userIsInteracting = true
                            appState.revealControls()
                        } else {
                            appState.bumpInteraction()
                        }
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

private struct PlaybackProgressSlider: View {
    @Binding var value: Double
    var onEditingChanged: (Bool) -> Void

    @State private var isDragging = false

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let clampedValue = min(max(value, 0), 1)
            let fillWidth = width * clampedValue
            let trackHeight: CGFloat = isDragging ? 11 : 8

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(isDragging ? 0.18 : 0.11))
                    .overlay {
                        Capsule()
                            .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                    }

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                DreamTheme.mistBlue.opacity(0.82),
                                DreamTheme.warmApricot.opacity(0.94),
                                DreamTheme.moonWhite.opacity(0.96)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(fillWidth, clampedValue > 0 ? trackHeight : 0))
                    .shadow(
                        color: DreamTheme.warmApricot.opacity(isDragging ? 0.22 : 0),
                        radius: isDragging ? 5 : 0
                    )
            }
            .frame(height: trackHeight)
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
        appState.showDemoControls ? TimerOption.demoCases : TimerOption.userFacingCases
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
