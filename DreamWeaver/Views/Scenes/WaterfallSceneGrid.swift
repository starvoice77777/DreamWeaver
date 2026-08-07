import SwiftUI

/// A vertically scrolling, two-column waterfall for browsing scenes.
/// Each lane owns its own stack so cards of different heights naturally cascade.
struct WaterfallSceneGrid: View {
    @EnvironmentObject private var appState: AppState

    let scenes: [DreamScene]
    var onToggleFavorite: (DreamScene) -> Void = { _ in }
    var onActivate: (DreamScene) -> Void

    private let horizontalPadding: CGFloat = 20
    private let columnSpacing: CGFloat = 12
    private let cardSpacing: CGFloat = 12

    var body: some View {
        GeometryReader { proxy in
            if scenes.isEmpty {
                ContentUnavailableView(
                    "没有匹配的场景",
                    systemImage: "sparkles",
                    description: nil
                )
                .foregroundStyle(DreamTheme.secondaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let cardWidth = max(
                    (proxy.size.width - horizontalPadding * 2 - columnSpacing) / 2,
                    120
                )

                ScrollView(.vertical, showsIndicators: false) {
                    HStack(alignment: .top, spacing: columnSpacing) {
                        waterfallColumn(
                            scenes: laneScenes(at: 0),
                            lane: 0,
                            cardWidth: cardWidth
                        )

                        waterfallColumn(
                            scenes: laneScenes(at: 1),
                            lane: 1,
                            cardWidth: cardWidth
                        )
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, 4)
                    .padding(.bottom, 48)
                }
                .scrollClipDisabled()
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func waterfallColumn(
        scenes: [WaterfallSceneEntry],
        lane: Int,
        cardWidth: CGFloat
    ) -> some View {
        LazyVStack(spacing: cardSpacing) {
            ForEach(scenes) { entry in
                WaterfallSceneCard(
                    scene: entry.scene,
                    isPlaying: appState.isPlaying && appState.currentSceneId == entry.scene.id,
                    height: cardHeight(for: entry.index, lane: lane, width: cardWidth),
                    onToggleFavorite: {
                        onToggleFavorite(entry.scene)
                    },
                    onTap: {
                        onActivate(entry.scene)
                    }
                )
            }
        }
        .frame(width: cardWidth, alignment: .top)
    }

    private func laneScenes(at lane: Int) -> [WaterfallSceneEntry] {
        scenes.enumerated().compactMap { index, scene in
            index % 2 == lane ? WaterfallSceneEntry(index: index, scene: scene) : nil
        }
    }

    private func cardHeight(for index: Int, lane: Int, width: CGFloat) -> CGFloat {
        let ratios: [CGFloat] = lane == 0 ? [1.16, 0.88, 1.04] : [0.94, 1.22, 0.98]
        return width * ratios[index % ratios.count]
    }
}

private struct WaterfallSceneEntry: Identifiable {
    let index: Int
    let scene: DreamScene

    var id: UUID { scene.id }
}

private struct WaterfallSceneCard: View {
    let scene: DreamScene
    let isPlaying: Bool
    let height: CGFloat
    var onToggleFavorite: () -> Void
    var onTap: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(scene.palette.gradient)
                .overlay {
                    GeometryReader { proxy in
                        if let cover = SceneCoverArt.image(for: scene.visualStyle) {
                            Image(uiImage: cover)
                                .resizable()
                                .scaledToFill()
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .clipped()
                        } else {
                            SceneMiniMotif(style: scene.visualStyle)
                                .frame(width: proxy.size.width, height: proxy.size.height)
                        }
                    }
                }
                .overlay {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.72)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                }

            VStack(alignment: .leading, spacing: 4) {
                if isPlaying {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform")
                            .font(.system(size: DreamIconSize.compact, weight: .semibold))
                        Text("正在播放")
                            .font(.system(size: 10, weight: .semibold))
                    }
                        .foregroundStyle(DreamTheme.moonWhite)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(DreamTheme.warmApricot.opacity(0.76), in: Capsule())
                }

                Spacer(minLength: 0)

                Text(scene.name)
                    .font(DreamTypography.cardTitle)
                    .foregroundStyle(DreamTheme.moonWhite)
                    .lineLimit(2)

                Text(scene.subtitle)
                    .font(DreamTypography.caption)
                    .foregroundStyle(DreamTheme.moonWhite.opacity(0.72))
                    .lineLimit(2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            Button(action: onToggleFavorite) {
                Image(systemName: scene.isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: DreamIconSize.secondary, weight: .semibold))
                    .foregroundStyle(
                        scene.isFavorite
                            ? DreamTheme.warmApricot
                            : DreamTheme.moonWhite.opacity(0.9)
                    )
                    .frame(width: 38, height: 38)
                    .background(.black.opacity(0.26), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(10)
            .accessibilityLabel(scene.isFavorite ? "取消收藏" : "收藏场景")
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    isPlaying
                        ? DreamTheme.componentAccent.opacity(0.9)
                        : Color.white.opacity(0.10),
                    lineWidth: isPlaying ? 1.5 : 1
                )
        }
        .shadow(
            color: DreamTheme.componentAccent.opacity(isPlaying ? 0.36 : 0.18),
            radius: isPlaying ? 18 : 10,
            y: 6
        )
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(scene.name)，\(scene.subtitle)")
        .accessibilityHint("轻点进入场景")
    }
}

#Preview {
    WaterfallSceneGrid(
        scenes: MockDataService.makeScenes(),
        onToggleFavorite: { _ in },
        onActivate: { _ in }
    )
    .background(Color.black)
    .environmentObject(AppState())
}
