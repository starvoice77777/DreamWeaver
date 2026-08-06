import SwiftUI

struct SceneLibraryView: View {
    @EnvironmentObject private var appState: AppState
    var onSceneActivated: ((DreamScene) -> Void)? = nil
    var onDismiss: (() -> Void)? = nil
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
                    Spacer()
                    Button {
                        withAnimation { showSearch.toggle() }
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(DreamTheme.moonWhite.opacity(0.82))
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.white.opacity(showSearch ? 0.12 : 0.06)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("搜索")
                    if let onDismiss {
                        Button(action: onDismiss) {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(DreamTheme.moonWhite.opacity(0.78))
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(Color.white.opacity(0.06)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("关闭场景选择")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                if showSearch {
                    TextField("搜索场景", text: $searchText)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .dreamRefractiveLiquidGlassCapsule(
                            accent: DreamTheme.mistBlue,
                            intensity: 0.72,
                            interactive: true
                        )
                        .padding(.horizontal, 20)
                        .foregroundStyle(DreamTheme.moonWhite)
                }

                GeometryReader { geo in
                    let sidePad: CGFloat = 20
                    let spacing: CGFloat = 10
                    let visibleCount: CGFloat = 4
                    // Icon-only filters stay compact while preserving a generous hit target.
                    let tagWidth = max(
                        (geo.size.width - sidePad * 2 - spacing * (visibleCount - 1)) / visibleCount,
                        48
                    )

                    ScrollView(.horizontal, showsIndicators: false) {
                        GlassEffectContainer(spacing: spacing) {
                            HStack(spacing: spacing) {
                                CapsuleChip(
                                    title: "全部",
                                    selected: selectedCategory == nil,
                                    usesLiquidGlass: false,
                                    systemImage: "square.grid.2x2.fill",
                                    fixedWidth: tagWidth
                                ) {
                                    selectedCategory = nil
                                }
                                ForEach(
                                    Array(
                                        SceneCategory.allCases
                                            .filter { $0 != .frequent }
                                            .prefix(3)
                                    )
                                ) { category in
                                    CapsuleChip(
                                        title: category.rawValue,
                                        selected: selectedCategory == category,
                                        usesLiquidGlass: false,
                                        systemImage: category.systemImage,
                                        fixedWidth: tagWidth
                                    ) {
                                        selectedCategory = category
                                    }
                                }
                            }
                        }
                        // Leave room for interactive glass scale / highlight bloom.
                        .padding(.horizontal, sidePad)
                        .padding(.vertical, 12)
                    }
                    .scrollClipDisabled()
                }
                .frame(height: 64)
                // Keep neighboring sections from colliding with the tag bloom.
                .padding(.vertical, -4)

                SpiralSceneCarousel(
                    scenes: filtered,
                    onToggleFavorite: { scene in
                        appState.toggleFavorite(sceneId: scene.id)
                    },
                    onActivate: { scene in
                        if let onSceneActivated {
                            onSceneActivated(scene)
                        } else {
                            appState.enterDream(sceneId: scene.id)
                        }
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
