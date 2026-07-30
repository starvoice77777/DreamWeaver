import SwiftUI

struct ScenePreviewView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    let scene: DreamScene
    @State private var fadingOut = false

    private var reduceMotion: Bool {
        appState.reduceMotion || systemReduceMotion
    }

    var body: some View {
        ZStack {
            SceneAtmosphereView(
                scene: scene,
                isPlaying: true,
                reduceMotion: reduceMotion,
                intensity: appState.animationIntensity
            )

            LinearGradient(
                colors: [.black.opacity(0.35), .clear, .black.opacity(0.75)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.backward")
                            .foregroundStyle(DreamTheme.moonWhite)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("返回")
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                Spacer()

                VStack(alignment: .leading, spacing: 14) {
                    Text(scene.name)
                        .font(.system(size: 34, weight: .ultraLight))
                        .foregroundStyle(DreamTheme.moonWhite)

                    Text(scene.description)
                        .font(.system(size: 15))
                        .foregroundStyle(DreamTheme.secondaryText)

                    Text("声音组成")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DreamTheme.mistBlue)
                        .padding(.top, 4)

                    FlowSoundTags(sources: scene.soundSources)

                    HStack(spacing: 12) {
                        previewAction(
                            scene.isFavorite ? "已收藏" : "收藏",
                            scene.isFavorite ? "heart.fill" : "heart"
                        ) {
                            appState.toggleFavorite(sceneId: scene.id)
                        }
                        previewAction("试听", "ear") {
                            appState.isPlaying = true
                        }
                    }

                    Button {
                        enterDream()
                    } label: {
                        Text("进入梦境")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(DreamTheme.midnight)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Capsule().fill(DreamTheme.moonWhite.opacity(0.95)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("进入梦境")
                    .padding(.top, 8)
                }
                .padding(24)
                .padding(.bottom, 20)
            }
        }
        .opacity(fadingOut ? 0 : 1)
        .animation(.easeInOut(duration: reduceMotion ? 0.2 : 0.75), value: fadingOut)
        .interactiveDismissDisabled(fadingOut)
    }

    private func previewAction(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                Text(title).font(.system(size: 11))
            }
            .foregroundStyle(DreamTheme.moonWhite.opacity(0.9))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.1)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private func enterDream() {
        guard !fadingOut else { return }
        withAnimation(.easeInOut(duration: reduceMotion ? 0.2 : 0.75)) {
            fadingOut = true
        }
        Task {
            // Let the preview dissolve first, then hand off to root transition.
            try? await Task.sleep(nanoseconds: reduceMotion ? 180_000_000 : 550_000_000)
            appState.enterDream(sceneId: scene.id)
        }
    }
}

struct FlowSoundTags: View {
    let sources: [SoundSource]

    var body: some View {
        FlexibleTagLayout(spacing: 8) {
            ForEach(sources) { source in
                HStack(spacing: 6) {
                    Image(systemName: source.symbolName)
                        .font(.system(size: 11))
                    Text(source.name)
                        .font(.system(size: 12))
                }
                .foregroundStyle(DreamTheme.moonWhite.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.white.opacity(0.1)))
            }
        }
    }
}

/// Simple wrapping layout for tags without external deps.
struct FlexibleTagLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, origin) in result.origins.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (origins: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (origins, CGSize(width: maxX, height: y + rowHeight))
    }
}

#Preview {
    ScenePreviewView(scene: MockDataService.makeScenes()[0])
        .environmentObject(AppState())
}
