import SwiftUI

struct SoundLibraryView: View {
    @EnvironmentObject private var appState: AppState
    @State private var segment: SoundLibrarySegment = .mine
    @State private var showSearch = false
    @State private var searchText = ""
    @State private var soundPendingDelete: SoundAsset?
    @State private var renameTarget: SoundAsset?
    @State private var renameText = ""
    @State private var detailTarget: SoundAsset?
    @State private var showUploadMock = false
    @State private var showRecordMock = false

    private var recordings: [SoundAsset] {
        filterList(appState.soundAssets.filter { $0.kind == .recording })
    }

    private var seeds: [SoundAsset] {
        filterList(appState.soundAssets.filter { $0.kind == .seed })
    }

    private var community: [SoundAsset] {
        filterList(appState.soundAssets.filter { $0.kind == .community })
    }

    private var favorites: [SoundAsset] {
        filterList(appState.soundAssets.filter(\.isFavorite))
    }

    private func filterList(_ list: [SoundAsset]) -> [SoundAsset] {
        guard !searchText.isEmpty else { return list }
        return list.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                header
                if showSearch {
                    TextField("搜索声音", text: $searchText)
                        .padding(12)
                        .dreamGlass(cornerRadius: 14)
                        .padding(.horizontal, 20)
                        .foregroundStyle(DreamTheme.moonWhite)
                }

                primaryActions
                    .padding(.horizontal, 20)

                segmentChips

                content
            }
            .background(DreamTheme.backgroundGradient.ignoresSafeArea())
            .navigationBarHidden(true)
            .alert("删除声音", isPresented: Binding(
                get: { soundPendingDelete != nil },
                set: { if !$0 { soundPendingDelete = nil } }
            )) {
                Button("删除", role: .destructive) {
                    if let id = soundPendingDelete?.id {
                        appState.deleteSound(id: id)
                    }
                    soundPendingDelete = nil
                }
                Button("取消", role: .cancel) { soundPendingDelete = nil }
            } message: {
                Text("确定删除「\(soundPendingDelete?.name ?? "")」吗？此操作仅影响本地演示数据。")
            }
            .alert("重命名", isPresented: Binding(
                get: { renameTarget != nil },
                set: { if !$0 { renameTarget = nil } }
            )) {
                TextField("名称", text: $renameText)
                Button("保存") {
                    if let id = renameTarget?.id {
                        appState.renameSound(id: id, name: renameText)
                    }
                    renameTarget = nil
                }
                Button("取消", role: .cancel) { renameTarget = nil }
            }
            .sheet(item: $detailTarget) { asset in
                SoundDetailSheet(asset: asset)
                    .environmentObject(appState)
                    .presentationDetents([.medium])
            }
            .fullScreenCover(isPresented: $appState.showSeedFlow) {
                SeedCreationFlow()
                    .environmentObject(appState)
            }
            .alert("上传本地文件", isPresented: $showUploadMock) {
                Button("选择演示文件") {
                    appState.addSoundAsset(
                        SoundAsset(
                            id: UUID(),
                            name: "本地录音 \(recordings.count + 1)",
                            kind: .recording,
                            durationSeconds: 96,
                            symbolName: "doc.fill",
                            avatarColor: 0x8197B5,
                            isFavorite: false,
                            relation: nil,
                            createdAt: Date(),
                            lastUsedAt: Date()
                        )
                    )
                    segment = .mine
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("演示模式不会读取真实文件。")
            }
            .alert("录制声音", isPresented: $showRecordMock) {
                Button("完成模拟录制") {
                    appState.addSoundAsset(
                        SoundAsset(
                            id: UUID(),
                            name: "新录音 \(recordings.count + 1)",
                            kind: .recording,
                            durationSeconds: 72,
                            symbolName: "mic.fill",
                            avatarColor: 0xA8B8D0,
                            isFavorite: false,
                            relation: nil,
                            createdAt: Date(),
                            lastUsedAt: Date()
                        )
                    )
                    segment = .mine
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("演示模式不会调用麦克风。")
            }
        }
    }

    private var header: some View {
        HStack {
            SectionHeader(title: "声音库")
            Button {
                showSearch.toggle()
            } label: {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DreamTheme.moonWhite)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("搜索")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var primaryActions: some View {
        HStack(spacing: 10) {
            actionChip(title: "录制声音", symbol: "mic.fill") { showRecordMock = true }
            actionChip(title: "上传本地文件", symbol: "square.and.arrow.up") { showUploadMock = true }
            actionChip(title: "创建声音种子", symbol: "leaf.fill") { appState.showSeedFlow = true }
        }
    }

    private func actionChip(title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 11))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(DreamTheme.moonWhite.opacity(0.9))
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private var segmentChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SoundLibrarySegment.allCases) { item in
                    CapsuleChip(title: item.rawValue, selected: segment == item) {
                        segment = item
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch segment {
        case .mine:
            mineContent
        case .community:
            listOrEmpty(
                community,
                emptySymbol: "person.3",
                emptyMessage: "社区还没有声音。稍后再来看看吧。",
                actionTitle: "去收藏页看看",
                action: { segment = .favorites }
            )
        case .favorites:
            listOrEmpty(
                favorites,
                emptySymbol: "heart",
                emptyMessage: "还没有收藏的声音。收藏后可与基本声音一起在声源添加中使用。",
                actionTitle: "浏览社区",
                action: { segment = .community }
            )
        }
    }

    private var mineContent: some View {
        Group {
            if recordings.isEmpty && seeds.isEmpty {
                EmptyStateView(
                    symbol: "waveform",
                    message: "还没有个人声音。可以录制、上传，或创建声音种子。",
                    actionTitle: "创建声音种子"
                ) {
                    appState.showSeedFlow = true
                }
                .padding(.top, 24)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 22) {
                        mineSection(title: "我的录音", items: recordings, emptyHint: "还没有录音") {
                            showRecordMock = true
                        }
                        mineSection(title: "我的声音种子", items: seeds, emptyHint: "还没有声音种子") {
                            appState.showSeedFlow = true
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 120)
                }
            }
        }
    }

    private func mineSection(
        title: String,
        items: [SoundAsset],
        emptyHint: String,
        emptyAction: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DreamTheme.secondaryText)

            if items.isEmpty {
                Button(action: emptyAction) {
                    Text(emptyHint + "，点此添加")
                        .font(.system(size: 13))
                        .foregroundStyle(DreamTheme.mistBlue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.04)))
                }
                .buttonStyle(.plain)
            } else {
                ForEach(items) { asset in
                    soundRow(asset)
                }
            }
        }
    }

    private func listOrEmpty(
        _ items: [SoundAsset],
        emptySymbol: String,
        emptyMessage: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Group {
            if items.isEmpty {
                EmptyStateView(symbol: emptySymbol, message: emptyMessage, actionTitle: actionTitle, action: action)
                    .padding(.top, 24)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(items) { asset in
                            soundRow(asset)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 120)
                }
            }
        }
    }

    private func soundRow(_ asset: SoundAsset) -> some View {
        SoundAssetRow(
            asset: asset,
            isPreviewing: appState.previewingSoundId == asset.id,
            canAddToScene: asset.isFavorite,
            onPreview: { appState.toggleSoundPreview(id: asset.id) },
            onFavorite: { appState.toggleSoundFavorite(id: asset.id) },
            onRename: {
                renameTarget = asset
                renameText = asset.name
            },
            onDetail: { detailTarget = asset },
            onAddToScene: {
                guard asset.isFavorite else { return }
                appState.addSource(
                    SoundSource(
                        name: asset.name,
                        symbolName: asset.symbolName,
                        assetId: asset.id
                    )
                )
                appState.selectedTab = .now
                appState.openSceneDetail()
            },
            onDelete: { soundPendingDelete = asset }
        )
    }
}

struct SoundAssetRow: View {
    let asset: SoundAsset
    var isPreviewing: Bool
    var canAddToScene: Bool
    var onPreview: () -> Void
    var onFavorite: () -> Void
    var onRename: () -> Void
    var onDetail: () -> Void
    var onAddToScene: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color(hex: asset.avatarColor).opacity(0.85))
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: asset.symbolName)
                        .foregroundStyle(DreamTheme.moonWhite)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(asset.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(DreamTheme.moonWhite)
                Text("\(asset.kind.rawValue) · \(asset.durationText)")
                    .font(.system(size: 12))
                    .foregroundStyle(DreamTheme.secondaryText)
            }

            Spacer()

            Button(action: onPreview) {
                Image(systemName: isPreviewing ? "pause.fill" : "play.fill")
                    .foregroundStyle(DreamTheme.moonWhite)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(isPreviewing ? "暂停试听" : "试听")

            Button(action: onFavorite) {
                Image(systemName: asset.isFavorite ? "heart.fill" : "heart")
                    .foregroundStyle(asset.isFavorite ? DreamTheme.warmApricot : DreamTheme.tertiaryText)
                    .frame(width: 36, height: 44)
            }
            .accessibilityLabel(asset.isFavorite ? "取消收藏" : "收藏")

            Menu {
                Button("重命名", action: onRename)
                Button("查看详情", action: onDetail)
                if canAddToScene {
                    Button("添加到场景", action: onAddToScene)
                } else {
                    Button("收藏后可添加到场景") {
                        if !asset.isFavorite { onFavorite() }
                    }
                }
                Button("导出") {}
                Button("删除", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(DreamTheme.secondaryText)
                    .frame(width: 36, height: 44)
            }
            .accessibilityLabel("更多操作")
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.06)))
    }
}

struct SoundDetailSheet: View {
    @EnvironmentObject private var appState: AppState
    let asset: SoundAsset

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(asset.name)
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(DreamTheme.moonWhite)
            Text("分类：\(asset.kind.rawValue)")
                .foregroundStyle(DreamTheme.secondaryText)
            Text("时长：\(asset.durationText)")
                .foregroundStyle(DreamTheme.secondaryText)
            if let relation = asset.relation {
                Text("关系：\(relation.rawValue)")
                    .foregroundStyle(DreamTheme.secondaryText)
            }
            Text(asset.isFavorite
                 ? "已收藏。可与基本声音一起在场景声源添加界面使用。"
                 : "收藏后，即可在场景声源添加界面调用此声音。基本声音无需收藏也可使用。")
                .font(.system(size: 13))
                .foregroundStyle(DreamTheme.tertiaryText)
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DreamTheme.deepBlue.ignoresSafeArea())
    }
}

#Preview {
    SoundLibraryView()
        .environmentObject(AppState())
}
