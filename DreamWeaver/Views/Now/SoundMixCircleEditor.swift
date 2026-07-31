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

/// Circular mix board: playing sources inside; basic + favorited sounds below.
struct SoundMixCircleEditor: View {
    @EnvironmentObject private var appState: AppState

    @State private var draggingPalette: MixPaletteDrag?
    @State private var draggingSourceId: UUID?
    @State private var finger: CGPoint = .zero
    @State private var boardWidth: CGFloat = 300
    @State private var appliedToast = ""

    private let circleSide: CGFloat = 260
    private let paletteRow: CGFloat = 108
    private let spacing: CGFloat = 18

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

    private var totalHeight: CGFloat { circleSide + spacing + paletteRow }
    private var circleSize: CGSize { CGSize(width: boardWidth, height: circleSide) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("声音组合")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(DreamTheme.moonWhite)

            Text(appState.mixBoardSelection.isMine
                 ? "圆内为正在播放的声源。基本声音随场景变化；已收藏声音可在任意场景使用。拖入添加、拖出移除，靠近中心声音更大。"
                 : "正在试听预设布局。预设不可编辑；返回「我的」后可继续调整，且不会丢失你的设置。")
                .font(.system(size: 12))
                .foregroundStyle(DreamTheme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)

            MixPresetBrowser(
                appliedToast: $appliedToast
            )

            GeometryReader { geo in
                let circleSize = CGSize(width: geo.size.width, height: circleSide)
                let center = CGPoint(x: circleSize.width / 2, y: circleSide / 2)

                ZStack(alignment: .top) {
                    circleLayer(size: circleSize, center: center)

                    paletteLayer(width: geo.size.width)
                        .frame(width: geo.size.width, height: paletteRow)
                        .offset(y: circleSide + spacing)
                        .opacity(canEditMix ? 1 : 0.4)
                        .allowsHitTesting(canEditMix)

                    ForEach(activeSources) { source in
                        sourceNode(source, circleSize: circleSize)
                            .allowsHitTesting(canEditMix)
                    }

                    if let drag = draggingPalette {
                        floatingChrome(for: drag)
                            .position(finger)
                            .allowsHitTesting(false)
                    }
                }
                .frame(width: geo.size.width, height: totalHeight)
                .contentShape(Rectangle())
                .coordinateSpace(name: "mixBoard")
                .onAppear { boardWidth = geo.size.width }
                .onChange(of: geo.size.width) { _, width in boardWidth = width }
            }
            .frame(height: totalHeight)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(alignment: .top) {
                if !appliedToast.isEmpty {
                    Text(appliedToast)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DreamTheme.moonWhite)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .dreamGlass(cornerRadius: 12)
                        .padding(.top, 8)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    @ViewBuilder
    private func floatingChrome(for drag: MixPaletteDrag) -> some View {
        switch drag {
        case .basic(let item):
            nodeChrome(symbol: item.symbolName, name: item.name, volume: 0.75, emphasized: true)
        case .favorite(let asset):
            nodeChrome(symbol: asset.symbolName, name: asset.name, volume: 0.75, emphasized: true)
        }
    }

    // MARK: - Layers

    private func circleLayer(size: CGSize, center: CGPoint) -> some View {
        let side = min(size.width, size.height)
        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: 0x1A2740).opacity(0.9), Color.white.opacity(0.03)],
                        center: .center,
                        startRadius: 8,
                        endRadius: side * 0.48
                    )
                )
                .frame(width: side * 0.92, height: side * 0.92)

            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                .frame(width: side * 0.92, height: side * 0.92)

            Circle()
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
                .frame(width: side * 0.58, height: side * 0.58)

            VStack(spacing: 4) {
                Circle()
                    .fill(DreamTheme.moonWhite.opacity(0.92))
                    .frame(width: 10, height: 10)
                Text("你")
                    .font(.system(size: 10))
                    .foregroundStyle(DreamTheme.tertiaryText)
            }
            .position(center)
            .accessibilityLabel("聆听位置")
        }
        .frame(width: size.width, height: circleSide)
    }

    private func paletteLayer(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("可添加声源")
                .font(.system(size: 11))
                .foregroundStyle(DreamTheme.secondaryText)
                .padding(.horizontal, 4)

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
                .padding(.horizontal, 2)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
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

    private func sourceNode(_ source: SoundSource, circleSize: CGSize) -> some View {
        let home = source.position.point(in: circleSize)
        let shown = draggingSourceId == source.id ? finger : home

        return nodeChrome(
            symbol: source.symbolName,
            name: source.name,
            volume: source.volume,
            emphasized: draggingSourceId == source.id
        )
        .position(shown)
        .highPriorityGesture(
            DragGesture(minimumDistance: 2, coordinateSpace: .named("mixBoard"))
                .onChanged { value in
                    appState.markSheetInteraction()
                    draggingSourceId = source.id
                    finger = value.location
                    if isInsideCircle(value.location, circleSize: circleSize) {
                        let clamped = clampToCircle(value.location, circleSize: circleSize)
                        appState.updateSourcePlacement(
                            id: source.id,
                            position: SpatialPosition.from(point: clamped, in: circleSize)
                        )
                    }
                }
                .onEnded { value in
                    defer { draggingSourceId = nil }
                    if isInsideCircle(value.location, circleSize: circleSize) {
                        let clamped = clampToCircle(value.location, circleSize: circleSize)
                        appState.updateSourcePlacement(
                            id: source.id,
                            position: SpatialPosition.from(point: clamped, in: circleSize)
                        )
                    } else {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            appState.removeSource(id: source.id)
                        }
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
                    appState.markSheetInteraction()
                    draggingPalette = .basic(item)
                    finger = value.location
                }
                .onEnded { value in
                    finishPaletteDrag(.basic(item), location: value.location)
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
                    appState.markSheetInteraction()
                    draggingPalette = .favorite(asset)
                    finger = value.location
                }
                .onEnded { value in
                    finishPaletteDrag(.favorite(asset), location: value.location)
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

    private func nodeChrome(symbol: String, name: String, volume: Double, emphasized: Bool) -> some View {
        let scale = 0.78 + volume * 0.5
        let iconSize: CGFloat = 14 * scale
        let side: CGFloat = 50 * scale
        let fillOpacity = 0.10 + volume * 0.08
        let textOpacity = 0.55 + volume * 0.4
        let stroke = emphasized ? DreamTheme.warmApricot.opacity(0.9) : Color.white.opacity(0.12)
        let lineWidth: CGFloat = emphasized ? 1.5 : 1

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
                    Circle().stroke(stroke, lineWidth: lineWidth)
                }
        }
        .shadow(color: .black.opacity(emphasized ? 0.35 : 0), radius: 8, y: 3)
    }

    private func finishPaletteDrag(_ drag: MixPaletteDrag, location: CGPoint) {
        defer { draggingPalette = nil }
        let size = circleSize
        guard isInsideCircle(location, circleSize: size) else { return }
        let clamped = clampToCircle(location, circleSize: size)
        let position = SpatialPosition.from(point: clamped, in: size)
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

    // MARK: - Geometry

    private func isInsideCircle(_ point: CGPoint, circleSize: CGSize) -> Bool {
        let center = CGPoint(x: circleSize.width / 2, y: circleSide / 2)
        let limit = min(circleSize.width, circleSide) * 0.42
        return hypot(point.x - center.x, point.y - center.y) <= limit * 1.08
            && point.y >= 0
            && point.y <= circleSide
    }

    private func clampToCircle(_ point: CGPoint, circleSize: CGSize) -> CGPoint {
        let center = CGPoint(x: circleSize.width / 2, y: circleSide / 2)
        let limit = min(circleSize.width, circleSide) * 0.42
        let dx = point.x - center.x
        let dy = point.y - center.y
        let distance = hypot(dx, dy)
        if distance <= limit || distance < 0.001 {
            return CGPoint(
                x: min(max(point.x, 0), circleSize.width),
                y: min(max(point.y, 0), circleSide)
            )
        }
        let scale = limit / distance
        return CGPoint(x: center.x + dx * scale, y: center.y + dy * scale)
    }
}

// MARK: - 「我的」+ read-only presets

struct MixPresetBrowser: View {
    @EnvironmentObject private var appState: AppState
    @Binding var appliedToast: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("声音布局")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DreamTheme.moonWhite)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    selectionChip(
                        title: "我的",
                        selected: appState.mixBoardSelection.isMine
                    ) {
                        appState.selectMineMixBoard()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appliedToast = "已回到「我的」"
                        }
                        clearToastLater(matching: "已回到「我的」")
                    }

                    ForEach(appState.mixPresets) { preset in
                        selectionChip(
                            title: preset.title,
                            selected: {
                                if case .preset(let id) = appState.mixBoardSelection {
                                    return id == preset.id
                                }
                                return false
                            }()
                        ) {
                            appState.selectMixPreset(preset)
                            withAnimation(.easeInOut(duration: 0.2)) {
                                appliedToast = "已切换「\(preset.title)」"
                            }
                            clearToastLater(matching: "已切换「\(preset.title)」")
                        }
                    }
                }
            }

            Text(appState.mixBoardSelection.isMine
                 ? "可自由调整圆内声源。切换预设不会清空「我的」布局。"
                 : "当前为预设试听，不可编辑。返回「我的」可继续调整。")
                .font(.system(size: 11))
                .foregroundStyle(DreamTheme.tertiaryText)
        }
    }

    private func selectionChip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: selected ? .medium : .regular))
                .foregroundStyle(selected ? DreamTheme.midnight : DreamTheme.moonWhite)
                .lineLimit(1)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(selected ? DreamTheme.moonWhite.opacity(0.92) : Color.white.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func clearToastLater(matching text: String) {
        Task {
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            withAnimation {
                if appliedToast == text {
                    appliedToast = ""
                }
            }
        }
    }
}

#Preview {
    ScrollView {
        SoundMixCircleEditor()
            .padding()
    }
    .background(DreamTheme.deepBlue)
    .environmentObject(AppState())
}
