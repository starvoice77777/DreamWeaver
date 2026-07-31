import SwiftUI

struct SceneLibraryView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedCategory: SceneCategory = .frequent
    @State private var searchText = ""
    @State private var showSearch = false
    @State private var sortByName = false

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
        if sortByName {
            list.sort { $0.name < $1.name }
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

                    Menu {
                        Button(sortByName ? "默认排序" : "按名称") {
                            sortByName.toggle()
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .foregroundStyle(DreamTheme.moonWhite)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("排序")
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
                            Button {
                                appState.previewScene = scene
                            } label: {
                                SceneCardView(
                                    scene: scene,
                                    isPlaying: appState.isPlaying && appState.currentSceneId == scene.id
                                )
                            }
                            .buttonStyle(.plain)
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
    let scene: DreamScene
    var isPlaying: Bool

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

                HStack(spacing: 8) {
                    if scene.isDemoPlayable {
                        Text("可试听")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(DreamTheme.midnight)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(DreamTheme.moonWhite.opacity(0.9)))
                    }
                    if isPlaying {
                        Image(systemName: "waveform")
                            .font(.system(size: 11))
                            .foregroundStyle(DreamTheme.warmApricot)
                            .accessibilityLabel("正在播放")
                    }
                    if scene.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(DreamTheme.warmApricot)
                    }
                }
                .padding(10)
            }

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
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .accessibilityElement(children: .combine)
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
