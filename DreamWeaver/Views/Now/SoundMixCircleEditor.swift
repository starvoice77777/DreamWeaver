import SwiftUI

struct BasicMixSound: Identifiable, Hashable {
    let id: String
    let name: String
    let symbolName: String

    static let all: [BasicMixSound] = [
        .init(id: "rain", name: "雨声", symbolName: "cloud.rain.fill"),
        .init(id: "wind", name: "风声", symbolName: "wind"),
        .init(id: "voice", name: "人声", symbolName: "person.wave.2.fill"),
        .init(id: "piano", name: "钢琴", symbolName: "pianokeys"),
        .init(id: "insect", name: "虫鸣", symbolName: "leaf.fill"),
        .init(id: "tide", name: "潮声", symbolName: "water.waves"),
        .init(id: "stream", name: "流水", symbolName: "drop.fill"),
        .init(id: "fire", name: "炉火", symbolName: "flame.fill")
    ]

    func resourceName(for style: SceneVisualStyle) -> String? {
        switch id {
        case "rain": return "rain_parasol"
        case "wind": return "wind_realistic"
        case "stream":
            switch style {
            case .hairCare:
                return "hair_wash"
            case .valleyStream, .moonLake:
                return "stream_nature"
            default:
                return nil
            }
        case "voice": return "voice_phrase_mom"
        default: return nil
        }
    }

    var layer: AudioLayerKind {
        switch id {
        case "voice": return .voice
        case "wind": return .ambience
        default: return .environment
        }
    }

    /// Basic sounds allowed for a scene; favorites remain universal elsewhere.
    static func available(for style: SceneVisualStyle) -> [BasicMixSound] {
        let ids = style.allowedBasicSoundIds
        return all.filter { ids.contains($0.id) }
    }
}

extension SceneVisualStyle {
    var allowedBasicSoundIds: Set<String> {
        switch self {
        case .rainEaves:
            return ["rain", "wind", "voice", "piano"]
        case .fireflies:
            return ["wind", "insect", "voice", "piano"]
        case .mistTide:
            return ["tide", "wind", "voice", "rain"]
        case .valleyStream:
            return ["stream", "wind", "voice", "insect"]
        case .moonLake:
            return ["stream", "wind", "piano", "voice"]
        case .starRiver:
            return ["piano", "wind", "voice"]
        case .warmLamp:
            return ["voice", "piano", "rain", "fire"]
        case .snowStudy:
            return ["wind", "voice", "piano", "rain"]
        case .wheatWind:
            return ["wind", "insect", "voice"]
        case .cloudBreath:
            return ["wind", "voice", "piano"]
        case .summerInsects:
            return ["insect", "wind", "voice", "rain"]
        case .fireplaceWhisper:
            return ["fire", "voice", "rain", "piano"]
        case .hairCare:
            return ["stream", "wind", "voice", "fire"]
        }
    }
}

private enum MixPaletteDrag: Equatable {
    case basic(BasicMixSound)
    case favorite(SoundAsset)
}

private struct ShatterBurst: Identifiable {
    let id = UUID()
    let origin: CGPoint
    let symbolName: String
    let born: Date
    let shards: [ShatterShard]

    struct ShatterShard: Identifiable {
        let id = UUID()
        let angle: Double
        let distance: CGFloat
        let size: CGFloat
        let spin: Double
    }

    static func make(at origin: CGPoint, symbol: String) -> ShatterBurst {
        let shards = (0..<14).map { i in
            ShatterShard(
                angle: Double(i) / 14 * .pi * 2 + Double.random(in: -0.2...0.2),
                distance: CGFloat.random(in: 28...72),
                size: CGFloat.random(in: 3...7),
                spin: Double.random(in: -120...120)
            )
        }
        return ShatterBurst(origin: origin, symbolName: symbol, born: Date(), shards: shards)
    }
}

/// Scene mix stage: disk on the upper golden-ratio point;
/// bottom dock crossfades between timer controls and the sound palette.
struct SoundMixCircleEditor: View {
    @EnvironmentObject private var appState: AppState
    @Binding var showTimerPicker: Bool

    @State private var draggingPalette: MixPaletteDrag?
    @State private var draggingSourceId: UUID?
    @State private var finger: CGPoint = .zero
    @State private var stageSize: CGSize = .zero
    /// Disk rings stay hidden until a source is moved / intro, then fade out after idle.
    @State private var diskVisible = false
    @State private var hideDiskTask: Task<Void, Never>?
    /// Waiting to show the scene-enter intro once the stage is actually visible.
    @State private var pendingSceneIntro = false
    /// Cold launch needs a short delay so ContentView fade-in finishes first.
    @State private var sceneIntroAfterLaunch = false
    @State private var sceneIntroTask: Task<Void, Never>?
    @State private var shatterBursts: [ShatterBurst] = []

    /// Upper golden-section point for the disk center.
    private let goldenFromTop: CGFloat = 0.382
    /// Dock center sits at 75% of the screen height.
    private let dockFromTop: CGFloat = 0.75
    private let maxDisk: CGFloat = 392
    private let dockHeight: CGFloat = 108
    private let diskFadeDuration: TimeInterval = 0.35
    /// How long rings stay after dragging a source (distinct from scene intro).
    private let diskIdleHideDelay: TimeInterval = 0.2
    /// Boot / enter-scene intro hold (not the drag idle delay).
    private let sceneIntroHold: TimeInterval = 2.0
    /// Let ContentView fade-in finish before counting the scene intro.
    private let launchRevealDelay: TimeInterval = 0.45

    private var activeSources: [SoundSource] {
        appState.currentScene.soundSources.filter(\.isEnabled)
    }

    private var favoriteAssets: [SoundAsset] {
        appState.soundAssets.filter(\.isFavorite)
    }

    private var availableBasicSounds: [BasicMixSound] {
        BasicMixSound.available(for: appState.currentScene.visualStyle)
    }

    private var canEditMix: Bool {
        appState.mixBoardSelection.isMine
    }

    private var showPalette: Bool {
        appState.showMixPalette
    }

    private var diskSide: CGFloat {
        guard stageSize.width > 0 else { return maxDisk }
        return min(stageSize.width - 16, maxDisk)
    }

    private var circleSize: CGSize {
        CGSize(width: diskSide, height: diskSide)
    }

    private var circleCenter: CGPoint {
        CGPoint(x: stageSize.width / 2, y: stageSize.height * goldenFromTop)
    }

    private var circleOrigin: CGPoint {
        CGPoint(x: circleCenter.x - diskSide / 2, y: circleCenter.y - diskSide / 2)
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

                ForEach(activeSources) { source in
                    sourceNode(
                        source,
                        circleSize: localCircleSize,
                        circleOrigin: origin,
                        circleCenter: center
                    )
                    .allowsHitTesting(canEditMix)
                    .zIndex(2)
                }

                listenerAnchor(at: center)
                    .zIndex(3)

                ForEach(shatterBursts) { burst in
                    ShatterBurstView(burst: burst)
                        .position(burst.origin)
                        .allowsHitTesting(false)
                        .zIndex(6)
                }

                bottomDock(width: dockWidth)
                    .frame(width: dockWidth, height: dockHeight)
                    .position(dockCenter)
                    .zIndex(4)

                if let drag = draggingPalette {
                    floatingChrome(for: drag)
                        .position(finger)
                        .allowsHitTesting(false)
                        .zIndex(7)
                }
            }
            .frame(width: size.width, height: size.height)
            .coordinateSpace(name: "mixBoard")
            .onAppear {
                stageSize = size
                requestSceneIntroDisk(afterLaunch: appState.showLaunch)
            }
            .onChange(of: size) { _, newSize in stageSize = newSize }
            .onChange(of: appState.currentSceneId) { _, _ in
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
        .animation(DreamTheme.chromeVisibilityAnimation, value: showPalette)
        .animation(.easeInOut(duration: 0.35), value: showTimerPicker)
        .accessibilityHint("点按聆听位置或拖动声源可打开音源选择；拖出圆盘可移除声源")
    }

    private func listenerAnchor(at center: CGPoint) -> some View {
        Button {
            guard canEditMix else { return }
            appState.openMixPalette()
            appState.bumpInteraction()
            beginDiskInteraction()
            scheduleDiskHide(after: 1.0)
        } label: {
            Image(systemName: "person.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(DreamTheme.moonWhite.opacity(0.9))
                .frame(width: 44, height: 44)
                .background {
                    Circle()
                        .stroke(DreamTheme.moonWhite.opacity(0.35), lineWidth: 1)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .position(center)
        .accessibilityLabel("聆听位置")
        .accessibilityHint("点按打开音源选择")
    }

    @ViewBuilder
    private func floatingChrome(for drag: MixPaletteDrag) -> some View {
        switch drag {
        case .basic(let item):
            nodeChrome(symbol: item.symbolName, name: item.name, volume: 0.75, pressed: true)
        case .favorite(let asset):
            nodeChrome(symbol: asset.symbolName, name: asset.name, volume: 0.75, pressed: true)
        }
    }

    private func bottomDock(width: CGFloat) -> some View {
        ZStack {
            NowControlsOverlay(showTimerPicker: $showTimerPicker)
                .opacity(showPalette ? 0 : 1)
                .allowsHitTesting(!showPalette)
                .offset(y: showPalette ? 6 : 0)

            mixPaletteDock()
                .opacity(showPalette ? 1 : 0)
                .allowsHitTesting(showPalette && canEditMix)
                .offset(y: showPalette ? 0 : 6)
        }
        .frame(width: width, height: dockHeight)
    }

    private func mixPaletteDock() -> some View {
        HStack(alignment: .center, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    paletteGroup(title: "基本") {
                        ForEach(availableBasicSounds) { item in
                            basicChip(item)
                        }
                    }

                    if !favoriteAssets.isEmpty {
                        Rectangle()
                            .fill(DreamTheme.divider)
                            .frame(width: 1, height: 52)
                            .padding(.top, 14)

                        paletteGroup(title: "收藏") {
                            ForEach(favoriteAssets) { asset in
                                favoriteChip(asset)
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
        .opacity(canEditMix ? 1 : 0.4)
    }

    // MARK: - Layers

    private func circleRings(size: CGSize) -> some View {
        let side = min(size.width, size.height)
        return ZStack {
            Circle()
                .stroke(DreamTheme.chromeStroke, lineWidth: 1)
                .frame(width: side * 0.92, height: side * 0.92)

            Circle()
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
                .frame(width: side * 0.58, height: side * 0.58)
        }
        .frame(width: size.width, height: size.height)
    }

    private func paletteGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(DreamTheme.tertiaryText)
            HStack(spacing: 12) {
                content()
            }
        }
    }

    // MARK: - Nodes

    private func sourceNode(
        _ source: SoundSource,
        circleSize: CGSize,
        circleOrigin: CGPoint,
        circleCenter: CGPoint
    ) -> some View {
        let local = source.position.point(in: circleSize)
        let home = CGPoint(x: circleOrigin.x + local.x, y: circleOrigin.y + local.y)
        let shown = draggingSourceId == source.id ? finger : home

        return nodeChrome(
            symbol: source.symbolName,
            name: source.name,
            volume: source.volume,
            pressed: draggingSourceId == source.id
        )
        .position(shown)
        .highPriorityGesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("mixBoard"))
                .onChanged { value in
                    appState.beginMixDrag()
                    appState.markMixInteraction()
                    beginDiskInteraction()
                    draggingSourceId = source.id
                    finger = value.location

                    if isInsideCircle(value.location, center: circleCenter, side: circleSize.width) {
                        let clamped = clampToCircle(value.location, center: circleCenter, side: circleSize.width)
                        let localPoint = CGPoint(x: clamped.x - circleOrigin.x, y: clamped.y - circleOrigin.y)
                        appState.updateSourcePlacement(
                            id: source.id,
                            position: SpatialPosition.from(point: localPoint, in: circleSize)
                        )
                    }
                }
                .onEnded { value in
                    defer {
                        draggingSourceId = nil
                        endDiskInteraction()
                        appState.endMixDrag()
                    }

                    if isInsideCircle(value.location, center: circleCenter, side: circleSize.width) {
                        let clamped = clampToCircle(value.location, center: circleCenter, side: circleSize.width)
                        let localPoint = CGPoint(x: clamped.x - circleOrigin.x, y: clamped.y - circleOrigin.y)
                        appState.updateSourcePlacement(
                            id: source.id,
                            position: SpatialPosition.from(point: localPoint, in: circleSize)
                        )
                    } else {
                        shatterAndRemove(source, at: value.location)
                    }
                }
        )
        .accessibilityLabel("\(source.name)，拖动调整位置与大小，拖出圆形可移除")
    }

    private func basicChip(_ item: BasicMixSound) -> some View {
        paletteIcon(
            symbol: item.symbolName,
            name: item.name,
            tint: Color.white.opacity(0.1),
            dimmed: {
                if case .basic(let current) = draggingPalette { return current.id == item.id }
                return false
            }()
        )
        .highPriorityGesture(
            DragGesture(minimumDistance: 4, coordinateSpace: .named("mixBoard"))
                .onChanged { value in
                    appState.beginMixDrag()
                    appState.markMixInteraction()
                    beginDiskInteraction()
                    draggingPalette = .basic(item)
                    finger = value.location
                }
                .onEnded { value in
                    finishPaletteDrag(.basic(item), location: value.location)
                    endDiskInteraction()
                    appState.endMixDrag()
                }
        )
        .accessibilityLabel("\(item.name)，基本声音，拖入圆内添加")
    }

    private func favoriteChip(_ asset: SoundAsset) -> some View {
        paletteIcon(
            symbol: asset.symbolName,
            name: asset.name,
            tint: Color(hex: asset.avatarColor).opacity(0.55),
            dimmed: {
                if case .favorite(let current) = draggingPalette { return current.id == asset.id }
                return false
            }()
        )
        .highPriorityGesture(
            DragGesture(minimumDistance: 4, coordinateSpace: .named("mixBoard"))
                .onChanged { value in
                    appState.beginMixDrag()
                    appState.markMixInteraction()
                    beginDiskInteraction()
                    draggingPalette = .favorite(asset)
                    finger = value.location
                }
                .onEnded { value in
                    finishPaletteDrag(.favorite(asset), location: value.location)
                    endDiskInteraction()
                    appState.endMixDrag()
                }
        )
        .accessibilityLabel("\(asset.name)，收藏声音，拖入圆内添加")
    }

    private func paletteIcon(symbol: String, name: String, tint: Color, dimmed: Bool) -> some View {
        VStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .frame(width: 42, height: 42)
                .background(Circle().fill(tint))
            Text(name)
                .font(.system(size: 10))
                .lineLimit(1)
                .frame(width: 52)
        }
        .foregroundStyle(DreamTheme.moonWhite.opacity(0.88))
        .opacity(dimmed ? 0.3 : 1)
    }

    private func nodeChrome(symbol: String, name: String, volume: Double, pressed: Bool) -> some View {
        let scale = 0.78 + volume * 0.5
        let iconSize: CGFloat = 14 * scale
        let side: CGFloat = 50 * scale
        let fillOpacity = 0.10 + volume * 0.08
        let textOpacity = 0.55 + volume * 0.4

        return VStack(spacing: 2) {
            Image(systemName: symbol)
                .font(.system(size: iconSize))
            Text(name)
                .font(.system(size: 9))
                .lineLimit(1)
        }
        .foregroundStyle(DreamTheme.moonWhite.opacity(textOpacity))
        .frame(width: side, height: side)
        .background {
            Circle()
                .fill(Color.white.opacity(fillOpacity))
                .overlay {
                    Circle().stroke(Color.white.opacity(0.12), lineWidth: 1)
                }
        }
        .scaleEffect(pressed ? 1.16 : 1.0)
        .shadow(color: .black.opacity(pressed ? 0.28 : 0), radius: pressed ? 10 : 0, y: 3)
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: pressed)
    }

    private func finishPaletteDrag(_ drag: MixPaletteDrag, location: CGPoint) {
        defer { draggingPalette = nil }
        let size = circleSize
        let center = circleCenter
        let origin = circleOrigin
        guard isInsideCircle(location, center: center, side: size.width) else { return }
        let clamped = clampToCircle(location, center: center, side: size.width)
        let localPoint = CGPoint(x: clamped.x - origin.x, y: clamped.y - origin.y)
        let position = SpatialPosition.from(point: localPoint, in: size)
        let volume = AppState.volume(fromRadius: position.radius)

        let source: SoundSource
        switch drag {
        case .basic(let item):
            source = SoundSource(
                name: item.name,
                symbolName: item.symbolName,
                isEnabled: true,
                volume: volume,
                position: position,
                resourceName: item.resourceName(for: appState.currentScene.visualStyle),
                layer: item.layer
            )
        case .favorite(let asset):
            source = SoundSource(
                name: asset.name,
                symbolName: asset.symbolName,
                isEnabled: true,
                volume: volume,
                position: position,
                assetId: asset.id,
                resourceName: asset.previewResourceName,
                layer: asset.kind == .seed ? .voice : .environment
            )
        }
        appState.addSource(source)
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

    private func beginDiskInteraction() {
        sceneIntroTask?.cancel()
        hideDiskTask?.cancel()
        hideDiskTask = nil
        pendingSceneIntro = false
        sceneIntroAfterLaunch = false
        guard !diskVisible else { return }
        withAnimation(.easeInOut(duration: diskFadeDuration)) {
            diskVisible = true
        }
    }

    private func endDiskInteraction() {
        scheduleDiskHide(after: diskIdleHideDelay)
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

    private func shatterAndRemove(_ source: SoundSource, at point: CGPoint) {
        let burst = ShatterBurst.make(at: point, symbol: source.symbolName)
        shatterBursts.append(burst)
        appState.removeSource(id: source.id)
        Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            await MainActor.run {
                shatterBursts.removeAll { $0.id == burst.id }
            }
        }
    }

    // MARK: - Geometry (stage coordinates)

    private func isInsideCircle(_ point: CGPoint, center: CGPoint, side: CGFloat) -> Bool {
        let limit = side * 0.42
        return hypot(point.x - center.x, point.y - center.y) <= limit * 1.08
    }

    private func clampToCircle(_ point: CGPoint, center: CGPoint, side: CGFloat) -> CGPoint {
        let limit = side * 0.42
        let dx = point.x - center.x
        let dy = point.y - center.y
        let distance = hypot(dx, dy)
        if distance <= limit || distance < 0.001 {
            return point
        }
        let scale = limit / distance
        return CGPoint(x: center.x + dx * scale, y: center.y + dy * scale)
    }
}

// MARK: - Shatter

private struct ShatterBurstView: View {
    let burst: ShatterBurst
    @State private var progress: CGFloat = 0

    var body: some View {
        ZStack {
            ForEach(burst.shards) { shard in
                Circle()
                    .fill(DreamTheme.moonWhite.opacity(0.85 * (1 - progress)))
                    .frame(width: shard.size, height: shard.size)
                    .offset(
                        x: cos(shard.angle) * shard.distance * progress,
                        y: sin(shard.angle) * shard.distance * progress
                    )
                    .rotationEffect(.degrees(shard.spin * Double(progress)))
            }

            Image(systemName: burst.symbolName)
                .font(.system(size: 12))
                .foregroundStyle(DreamTheme.moonWhite.opacity(0.7 * (1 - min(progress * 1.4, 1))))
                .scaleEffect(1 - 0.55 * progress)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.65)) {
                progress = 1
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
