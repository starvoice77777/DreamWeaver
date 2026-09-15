import SwiftUI
import UniformTypeIdentifiers

struct SceneStageView: View {
    let placements: [SceneSlotKind: SoundElement]
    let activeElements: [SoundElement]
    let sceneTitle: String
    let isPlaying: Bool
    let pendingElementID: String?
    let onDropElementID: (String) -> Void
    let onCanvasTap: () -> Void
    let onRemove: (SceneSlotKind) -> Void

    @State private var isCanvasTargeted = false
    @State private var isBreathing = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(IllustrationPalette.paper)

            SceneIllustrationCanvas(
                placements: placements,
                isPlaying: isPlaying,
                isBreathing: isBreathing
            )
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))

            VStack(spacing: 0) {
                if activeElements.isEmpty {
                    CanvasEmptyState(isPending: pendingElementID != nil)
                } else {
                    ActiveSoundStrip(elements: activeElements, onRemove: onRemove)
                        .padding(.top, 116)

                    Spacer()

                    VStack(spacing: 7) {
                        Text(sceneTitle)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(IllustrationPalette.ink)

                        Text(pendingElementID == nil ? "拖入更多声音，让画面继续生长" : "松手或点击画布，加入这束声音")
                            .font(.caption)
                            .foregroundStyle(IllustrationPalette.line)
                    }

                    Spacer()
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)

            if isCanvasTargeted {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(IllustrationPalette.ink.opacity(0.55), style: StrokeStyle(lineWidth: 2, dash: [8, 7]))
                    .padding(5)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .onTapGesture {
            if pendingElementID != nil { onCanvasTap() }
        }
        .onDrop(of: [UTType.text], isTargeted: $isCanvasTargeted, perform: handleDrop)
        .onAppear { isBreathing = true }
        .animation(.easeInOut(duration: 6).repeatForever(autoreverses: true), value: isBreathing)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(activeElements.isEmpty ? "空白梦境画布" : "已编织场景：\(sceneTitle)")
        .accessibilityHint(pendingElementID == nil ? "拖动声音到画布，或先从下方选择声音" : "点击画布，将已选择的声音加入场景")
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        if provider.canLoadObject(ofClass: NSString.self) {
            provider.loadObject(ofClass: NSString.self) { object, _ in
                if let id = object as? String {
                    DispatchQueue.main.async { onDropElementID(id) }
                }
            }
            return true
        }

        provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
            let id = (item as? Data).flatMap { String(data: $0, encoding: .utf8) } ?? (item as? String)
            if let id { DispatchQueue.main.async { onDropElementID(id) } }
        }
        return true
    }
}

enum IllustrationPalette {
    static let paper = Color(red: 0.975, green: 0.968, blue: 0.945)
    static let ink = Color(red: 0.055, green: 0.09, blue: 0.28)
    static let line = Color(red: 0.50, green: 0.55, blue: 0.62)
    static let paleLine = Color(red: 0.78, green: 0.80, blue: 0.82)
    static let warm = Color(red: 0.76, green: 0.52, blue: 0.27)
    static let mist = Color(red: 0.82, green: 0.87, blue: 0.90)
}

private struct CanvasEmptyState: View {
    let isPending: Bool

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: isPending ? "hand.tap" : "circle.dashed")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(IllustrationPalette.line.opacity(0.62))
            Text(isPending ? "把这束声音放进画里" : "一张空白的梦境画布")
                .font(.title3.weight(.medium))
                .foregroundStyle(IllustrationPalette.ink)
            Text(isPending ? "点击画布，完成第一次编织" : "从下方选择或拖入声音元素")
                .font(.subheadline)
                .foregroundStyle(IllustrationPalette.line)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ActiveSoundStrip: View {
    let elements: [SoundElement]
    let onRemove: (SceneSlotKind) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(elements) { element in
                    Button { onRemove(element.defaultSlot) } label: {
                        Label(element.name, systemImage: element.systemImage)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(IllustrationPalette.ink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(.white.opacity(0.82), in: Capsule())
                            .overlay(Capsule().stroke(IllustrationPalette.paleLine, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("移除声音：\(element.name)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct SceneIllustrationCanvas: View {
    let placements: [SceneSlotKind: SoundElement]
    let isPlaying: Bool
    let isBreathing: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let environment = placements[.environment] {
                    IllustrationObject(kind: environment.illustrationKind, isPlaying: isPlaying, isBreathing: isBreathing)
                        .frame(width: proxy.size.width * 0.74, height: proxy.size.height * 0.25)
                        .position(x: proxy.size.width * 0.34, y: proxy.size.height * 0.20)
                }

                if let atmosphere = placements[.atmosphere] {
                    IllustrationObject(kind: atmosphere.illustrationKind, isPlaying: isPlaying, isBreathing: isBreathing)
                        .frame(width: proxy.size.width * 0.86, height: proxy.size.height * 0.28)
                        .position(x: proxy.size.width * 0.54, y: proxy.size.height * 0.38)
                }

                if let anchor = placements[.anchor] {
                    IllustrationObject(kind: anchor.illustrationKind, isPlaying: isPlaying, isBreathing: isBreathing)
                        .frame(width: proxy.size.width * 0.52, height: proxy.size.height * 0.32)
                        .position(x: proxy.size.width * 0.52, y: proxy.size.height * 0.61)
                }

                if let detail = placements[.detail] {
                    IllustrationObject(kind: detail.illustrationKind, isPlaying: isPlaying, isBreathing: isBreathing)
                        .frame(width: proxy.size.width * 0.42, height: proxy.size.height * 0.22)
                        .position(x: proxy.size.width * 0.28, y: proxy.size.height * 0.80)
                }

                if let asmr = placements[.humanASMR] {
                    IllustrationObject(kind: asmr.illustrationKind, isPlaying: isPlaying, isBreathing: isBreathing)
                        .frame(width: proxy.size.width * 0.46, height: proxy.size.height * 0.20)
                        .position(x: proxy.size.width * 0.76, y: proxy.size.height * 0.82)
                }

                if let event = placements[.event] {
                    IllustrationObject(kind: event.illustrationKind, isPlaying: isPlaying, isBreathing: isBreathing)
                        .frame(width: proxy.size.width * 0.38, height: proxy.size.height * 0.24)
                        .position(x: proxy.size.width * 0.77, y: proxy.size.height * 0.53)
                }
            }
        }
    }
}

private struct IllustrationObject: View {
    let kind: IllustrationKind
    let isPlaying: Bool
    let isBreathing: Bool

    @ViewBuilder
    var body: some View {
        switch kind {
        case .nightWindow: WindowIllustration(isBreathing: isBreathing)
        case .rain: RainIllustration(isBreathing: isBreathing)
        case .fireplace: FireplaceIllustration(isPlaying: isPlaying, isBreathing: isBreathing)
        case .campfire: CampfireIllustration(isPlaying: isPlaying)
        case .book: BookIllustration(isBreathing: isBreathing)
        case .footprints: FootprintsIllustration(isBreathing: isBreathing)
        case .asmr: ASMRIllustration(isBreathing: isBreathing)
        case .clock: ClockIllustration(isBreathing: isBreathing)
        case .ambient: AmbientIllustration()
        }
    }
}

private struct WindowIllustration: View {
    let isBreathing: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(IllustrationPalette.mist.opacity(0.22))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(IllustrationPalette.line, lineWidth: 1.5))
            Rectangle().fill(IllustrationPalette.line).frame(width: 1.5)
            Rectangle().fill(IllustrationPalette.line).frame(height: 1.5)
            Image(systemName: "moon.fill")
                .font(.system(size: 42, weight: .regular))
                .foregroundStyle(IllustrationPalette.ink)
                .frame(width: 42, height: 42)
                .offset(x: -26, y: -16)
            HStack(spacing: 10) {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(IllustrationPalette.line.opacity(0.58))
                        .frame(width: 3, height: 3)
                        .offset(y: isBreathing ? CGFloat(index) : CGFloat(-index))
                }
            }
            .offset(y: 17)
        }
    }
}

private struct RainIllustration: View {
    let isBreathing: Bool

    var body: some View {
        ZStack {
            Ellipse().fill(IllustrationPalette.mist.opacity(0.28)).frame(width: 230, height: 76)
            HStack(spacing: 15) {
                ForEach(0..<10, id: \.self) { index in
                    Capsule()
                        .stroke(IllustrationPalette.line.opacity(0.66), lineWidth: 1.2)
                        .frame(width: 1.5, height: CGFloat(18 + index % 4 * 7))
                        .rotationEffect(.degrees(12))
                        .offset(y: isBreathing ? 8 : -5)
                }
            }
        }
    }
}

private struct FireplaceIllustration: View {
    let isPlaying: Bool
    let isBreathing: Bool

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(IllustrationPalette.warm.opacity(0.15))
                .overlay(Rectangle().stroke(IllustrationPalette.line, lineWidth: 1.4))
                .frame(height: 10)
            RoundedRectangle(cornerRadius: 3)
                .fill(IllustrationPalette.warm.opacity(0.09))
                .overlay {
                    VStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(IllustrationPalette.warm.opacity(isPlaying ? 0.88 : 0.58))
                            .scaleEffect(isBreathing ? 1.08 : 0.94)
                        Rectangle().fill(IllustrationPalette.ink.opacity(0.48)).frame(width: 64, height: 2)
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(IllustrationPalette.line, lineWidth: 1.4))
            Rectangle()
                .fill(IllustrationPalette.paleLine)
                .frame(height: 8)
        }
    }
}

private struct CampfireIllustration: View {
    let isPlaying: Bool

    var body: some View {
        ZStack {
            Circle().fill(IllustrationPalette.warm.opacity(0.14)).frame(width: 120, height: 70)
            Image(systemName: "flame.fill")
                .font(.system(size: 42))
                .foregroundStyle(IllustrationPalette.warm.opacity(isPlaying ? 0.86 : 0.58))
            HStack(spacing: -5) {
                Capsule().fill(IllustrationPalette.line).frame(width: 52, height: 7).rotationEffect(.degrees(16))
                Capsule().fill(IllustrationPalette.line).frame(width: 52, height: 7).rotationEffect(.degrees(-16))
            }
            .offset(y: 25)
        }
    }
}

private struct BookIllustration: View {
    let isBreathing: Bool

    var body: some View {
        HStack(spacing: 0) {
            page
                .rotationEffect(.degrees(isBreathing ? -2 : 2))
            page
                .scaleEffect(x: -1, y: 1)
                .rotationEffect(.degrees(isBreathing ? 2 : -2))
        }
        .overlay {
            Rectangle().fill(IllustrationPalette.line).frame(width: 1, height: 62)
        }
    }

    private var page: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(.white.opacity(0.62))
            .overlay {
                VStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle().fill(IllustrationPalette.paleLine).frame(height: 1)
                    }
                }
                .padding(.horizontal, 13)
            }
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(IllustrationPalette.line, lineWidth: 1.2))
            .frame(width: 72, height: 62)
    }
}

private struct FootprintsIllustration: View {
    let isBreathing: Bool

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { index in
                Image(systemName: "shoeprints.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(IllustrationPalette.line.opacity(0.38 + Double(index) * 0.10))
                    .rotationEffect(.degrees(index.isMultiple(of: 2) ? -12 : 12))
                    .offset(y: isBreathing ? CGFloat(index) * -3 : CGFloat(index) * 2)
            }
        }
        .rotationEffect(.degrees(-8))
    }
}

private struct ASMRIllustration: View {
    let isBreathing: Bool

    var body: some View {
        HStack(spacing: 5) {
            Circle().stroke(IllustrationPalette.line, lineWidth: 1.4).frame(width: 26, height: 26)
            ForEach(0..<9, id: \.self) { index in
                Capsule()
                    .fill(IllustrationPalette.ink.opacity(0.42))
                    .frame(width: 2, height: CGFloat(8 + index % 4 * 7))
                    .scaleEffect(y: isBreathing ? 1.18 : 0.84)
            }
        }
    }
}

private struct ClockIllustration: View {
    let isBreathing: Bool

    var body: some View {
        ZStack {
            Circle().fill(.white.opacity(0.42)).overlay(Circle().stroke(IllustrationPalette.line, lineWidth: 1.4))
            Rectangle().fill(IllustrationPalette.ink).frame(width: 1.5, height: 27).offset(y: -12)
                .rotationEffect(.degrees(isBreathing ? 4 : -4))
            Rectangle().fill(IllustrationPalette.ink).frame(width: 1.5, height: 20).offset(x: 9, y: 7).rotationEffect(.degrees(120))
            Circle().fill(IllustrationPalette.ink).frame(width: 5, height: 5)
        }
        .padding(15)
    }
}

private struct AmbientIllustration: View {
    var body: some View {
        Circle().stroke(IllustrationPalette.paleLine, lineWidth: 1).padding(22)
    }
}
