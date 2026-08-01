import SwiftUI

struct SceneLibraryView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedCategory: SceneCategory = .frequent
    @State private var searchText = ""
    @State private var showSearch = false

    private var filtered: [DreamScene] {
        var list = appState.scenes
        switch selectedCategory {
        case .frequent:
            list = list.filter(\.isFrequentlyUsed)
        case .favorites:
            list = list.filter(\.isFavorite)
        default:
            list = list.filter { $0.category == selectedCategory || $0.tags.contains(selectedCategory.rawValue) }
        }
        if !searchText.isEmpty {
            list = list.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
                    || $0.subtitle.localizedCaseInsensitiveContains(searchText)
            }
        }
        return list
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    SectionHeader(title: "全部")
                    Button {
                        withAnimation { showSearch.toggle() }
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(DreamTheme.moonWhite)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("搜索")

                    Button {
                        // TODO: 用户自行创建场景入口（交互待实现）
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(DreamTheme.moonWhite)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("创建场景")
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                if showSearch {
                    TextField("搜索场景", text: $searchText)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .dreamGlass(cornerRadius: 14)
                        .padding(.horizontal, 20)
                        .foregroundStyle(DreamTheme.moonWhite)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(SceneCategory.allCases) { category in
                            CapsuleChip(title: category.rawValue, selected: selectedCategory == category) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }

                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
                        spacing: 14
                    ) {
                        ForEach(filtered) { scene in
                            SceneCardView(
                                scene: scene,
                                isPlaying: appState.isPlaying && appState.currentSceneId == scene.id
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 120)
                }
            }
            .background(DreamTheme.backgroundGradient.ignoresSafeArea())
            .navigationBarHidden(true)
        }
    }
}

struct SceneCardView: View {
    @EnvironmentObject private var appState: AppState
    let scene: DreamScene
    var isPlaying: Bool

    private var isFavorite: Bool {
        appState.scenes.first(where: { $0.id == scene.id })?.isFavorite ?? scene.isFavorite
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(scene.palette.gradient)
                    .frame(height: 120)
                    .overlay {
                        SceneMiniMotif(style: scene.visualStyle)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .overlay(alignment: .topLeading) {
                        if isPlaying {
                            Image(systemName: "waveform")
                                .font(.system(size: 11))
                                .foregroundStyle(DreamTheme.warmApricot)
                                .padding(10)
                                .accessibilityLabel("正在播放")
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if scene.isDemoPlayable {
                            Text("可试听")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(DreamTheme.midnight)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(DreamTheme.moonWhite.opacity(0.9)))
                                .padding(8)
                        }
                    }

                Button {
                    appState.toggleFavorite(sceneId: scene.id)
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(isFavorite ? DreamTheme.warmApricot : DreamTheme.moonWhite.opacity(0.85))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(6)
                .accessibilityLabel(isFavorite ? "取消收藏" : "收藏")
            }
            .onTapGesture {
                appState.enterDream(sceneId: scene.id)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(scene.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(DreamTheme.moonWhite)
                    .lineLimit(1)

                Text(scene.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(DreamTheme.secondaryText)
                    .lineLimit(2)
                    .frame(height: 30, alignment: .top)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                appState.enterDream(sceneId: scene.id)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(scene.name)，\(scene.subtitle)")
    }
}

struct SceneMiniMotif: View {
    let style: SceneVisualStyle

    var body: some View {
        Canvas { context, size in
            for i in 0..<12 {
                let x = CGFloat(i) / 12 * size.width
                let y = size.height * (0.3 + CGFloat(i % 3) * 0.15)
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: 4, height: 4)),
                    with: .color(.white.opacity(0.2))
                )
            }
            context.fill(
                Path(ellipseIn: CGRect(x: size.width * 0.55, y: size.height * 0.2, width: 28, height: 28)),
                with: .color(.white.opacity(0.18))
            )
        }
        .opacity(0.9)
        .allowsHitTesting(false)
    }
}

#Preview {
    SceneLibraryView()
        .environmentObject(AppState())
}
