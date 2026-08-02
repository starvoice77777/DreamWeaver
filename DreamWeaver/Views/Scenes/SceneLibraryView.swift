import SwiftUI

struct SceneLibraryView: View {
    @EnvironmentObject private var appState: AppState
    /// `nil` = 全部场景（默认）；否则按分类筛选。
    @State private var selectedCategory: SceneCategory?
    @State private var searchText = ""
    @State private var showSearch = false

    private var filtered: [DreamScene] {
        var list = appState.scenes
        if let selectedCategory {
            switch selectedCategory {
            case .frequent:
                list = list.filter(\.isFrequentlyUsed)
            case .favorites:
                list = list.filter(\.isFavorite)
            default:
                list = list.filter {
                    $0.category == selectedCategory || $0.tags.contains(selectedCategory.rawValue)
                }
            }
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
                        CapsuleChip(title: "全部", selected: selectedCategory == nil) {
                            selectedCategory = nil
                        }
                        ForEach(SceneCategory.allCases) { category in
                            CapsuleChip(
                                title: category.rawValue,
                                selected: selectedCategory == category
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }

                SpiralSceneCarousel(
                    scenes: filtered,
                    onActivate: { scene in
                        appState.enterDream(sceneId: scene.id)
                    }
                )
                .padding(.bottom, 88)
            }
            .background(
                ZStack {
                    Color.black
                    RadialGradient(
                        colors: [
                            DreamTheme.deepBlue.opacity(0.54),
                            DreamTheme.midnight.opacity(0.34),
                            Color.black
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 420
                    )
                }
                .ignoresSafeArea()
            )
            .navigationBarHidden(true)
        }
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
