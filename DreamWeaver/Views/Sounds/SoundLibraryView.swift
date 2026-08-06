import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

private enum LibraryHubSection: String, CaseIterable, Identifiable {
    case existing = "已有"
    case custom = "自定义"

    var id: String { rawValue }
}

private enum ExistingLibraryGroup: String, Identifiable {
    case materials = "素材"
    case seeds = "人声种子"

    var id: String { rawValue }
}

private let existingPreviewLimit = 3

private enum AudioUploadChoice: String, CaseIterable, Identifiable {
    case record = "现场录音"
    case file = "上传文件"

    var id: String { rawValue }
}

struct SoundLibraryView: View {
    @EnvironmentObject private var appState: AppState
    var title: String = "声音库"
    var onCreateRequested: (() -> Void)? = nil
    var onDismiss: (() -> Void)? = nil

    @State private var section: LibraryHubSection = .existing
    @State private var showSearch = false
    @State private var searchText = ""
    @State private var soundPendingDelete: SoundAsset?
    @State private var deleteImpact: LibraryDeleteImpact?
    @State private var isPreparingDelete = false
    @State private var renameTarget: SoundAsset?
    @State private var renameText = ""
    @State private var detailTarget: SoundAsset?

    @State private var showUploadChooser = false

    @State private var showUploadMock = false
    @State private var showRecordMock = false
    @State private var showFileImporter = false
    @State private var isUploading = false
    @State private var libraryNotice: String?
    @State private var showLoginHint = false
    @State private var expandedLibraryGroup: ExistingLibraryGroup?

    private var canRemoteUpload: Bool {
        appState.contentBackendMode == .remote
            && appState.isRemoteAuthenticated
            && appState.remoteLibraryService != nil
    }

    /// Uploaded recordings + official/community materials shown as one “素材” group.
    private var materialAssets: [SoundAsset] {
        filterList(
            appState.soundAssets.filter { $0.kind == .recording || $0.kind == .community }
        )
    }

    private var seedAssets: [SoundAsset] {
        filterList(appState.soundAssets.filter { $0.kind == .seed })
    }

    private func filterList(_ list: [SoundAsset]) -> [SoundAsset] {
        guard !searchText.isEmpty else { return list }
        return list.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if showSearch {
                        TextField("搜索声音", text: $searchText)
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

                    existingContent
                }
                .background(DreamTheme.backgroundGradient.ignoresSafeArea())

                if isUploading || isPreparingDelete {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                    ProgressView(isUploading ? "正在上传…" : "检查引用…")
                        .padding(20)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(DreamTheme.moonWhite)
                }
            }
            .navigationBarHidden(true)
            .confirmationDialog("音频上传", isPresented: $showUploadChooser, titleVisibility: .visible) {
                Button("现场录音") { beginRecordUpload() }
                Button("上传文件") { beginFileUpload() }
                Button("取消", role: .cancel) {}
            }
            .sheet(item: $expandedLibraryGroup) { group in
                ExistingLibraryFullList(
                    title: group.rawValue,
                    items: group == .materials ? materialAssets : seedAssets,
                    row: { asset in
                        soundRow(asset)
                    },
                    onClose: { expandedLibraryGroup = nil }
                )
                .presentationDetents([.medium, .large])
            }
            .alert("删除声音", isPresented: Binding(
                get: { soundPendingDelete != nil },
                set: { if !$0 { clearDeletePending() } }
            )) {
                Button("删除", role: .destructive) {
                    if let id = soundPendingDelete?.id {
                        appState.deleteSound(id: id)
                    }
                    clearDeletePending()
                }
                Button("取消", role: .cancel) { clearDeletePending() }
            } message: {
                Text(deleteConfirmMessage)
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
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: Self.uploadContentTypes,
                allowsMultipleSelection: false
            ) { result in
                handleImportedFiles(result)
            }
            .alert("上传本地文件", isPresented: $showUploadMock) {
                Button("选择演示文件") {
                    appState.addSoundAsset(
                        SoundAsset(
                            id: UUID(),
                            name: "本地录音 \(materialAssets.filter { $0.kind == .recording }.count + 1)",
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
                    section = .existing
                }
                Button("取消", role: .cancel) {}
            }
            .alert("录制声音", isPresented: $showRecordMock) {
                Button("完成模拟录制") {
                    appState.addSoundAsset(
                        SoundAsset(
                            id: UUID(),
                            name: "新录音 \(materialAssets.filter { $0.kind == .recording }.count + 1)",
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
                    section = .existing
                }
                Button("取消", role: .cancel) {}
            }
            .alert("需要登录", isPresented: $showLoginHint) {
                Button("好", role: .cancel) {}
            } message: {
                Text("请先登录。")
            }
            .alert("提示", isPresented: Binding(
                get: { libraryNotice != nil },
                set: { if !$0 { libraryNotice = nil } }
            )) {
                Button("好", role: .cancel) { libraryNotice = nil }
            } message: {
                Text(libraryNotice ?? "")
            }
        }
    }

    private var deleteConfirmMessage: String {
        let name = soundPendingDelete?.name ?? ""
        guard let impact = deleteImpact else {
            return "确定删除「\(name)」吗？"
        }
        if impact.totalReferences <= 0 {
            return "确定删除「\(name)」吗？当前没有场景引用此声音。"
        }
        let sceneNames = impact.affectedScenes.prefix(3).map(\.name).joined(separator: "、")
        let more = impact.affectedScenes.count > 3 ? " 等" : ""
        return "确定删除「\(name)」吗？将影响 \(impact.totalReferences) 处引用（场景：\(sceneNames)\(more)）。删除后相关混音中的声源会被移除。"
    }

    private static let uploadContentTypes: [UTType] = {
        var types: [UTType] = [.audio, .mp3, .wav, .aiff]
        if let m4a = UTType(filenameExtension: "m4a") { types.append(m4a) }
        if let caf = UTType(filenameExtension: "caf") { types.append(caf) }
        return types
    }()

    // MARK: - Header & Switcher

    private var header: some View {
        HStack {
            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(DreamTheme.warmApricot)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.white.opacity(0.05)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("返回创建")
            }

            SectionHeader(title: title)
            GlassEffectContainer(spacing: 10) {
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
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var sectionSwitcher: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 8) {
                ForEach(LibraryHubSection.allCases) { item in
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            section = item
                        }
                    } label: {
                        Text(item.rawValue)
                            .font(section == item ? DreamTypography.callout.bold() : DreamTypography.callout)
                            .foregroundStyle(
                                section == item
                                    ? DreamTheme.moonWhite
                                    : DreamTheme.moonWhite.opacity(0.72)
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .scaleEffect(section == item ? 1.03 : 1)
                            .animation(.spring(response: 0.28, dampingFraction: 0.78), value: section)
                            .dreamRefractiveLiquidGlassCapsule(
                                accent: section == item ? DreamTheme.warmApricot : DreamTheme.mistBlue,
                                intensity: section == item ? 0.95 : 0.62,
                                interactive: true
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.rawValue)
                    .accessibilityAddTraits(section == item ? .isSelected : [])
                }
            }
        }
    }

    // MARK: - Existing

    private var existingContent: some View {
        Group {
            if materialAssets.isEmpty && seedAssets.isEmpty {
                EmptyStateView(
                    symbol: "waveform",
                    message: "还没有声音素材。可以先去「创建」录制或上传声音。",
                    actionTitle: "去创建"
                ) {
                    if let onCreateRequested {
                        onCreateRequested()
                    } else {
                        appState.selectedTab = .create
                    }
                }
                .padding(.top, 24)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 22) {
                        existingSection(
                            title: "素材",
                            group: .materials,
                            items: materialAssets,
                            emptyHint: "还没有上传或官方素材"
                        )
                        existingSection(
                            title: "人声种子",
                            group: .seeds,
                            items: seedAssets,
                            emptyHint: "还没有人声种子"
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 120)
                }
            }
        }
    }

    private func existingSection(
        title: String,
        group: ExistingLibraryGroup,
        items: [SoundAsset],
        emptyHint: String
    ) -> some View {
        let previewItems = Array(items.prefix(existingPreviewLimit))
        let hasMore = items.count > existingPreviewLimit

        return VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(DreamTypography.callout)
                .foregroundStyle(DreamTheme.secondaryText)

            if items.isEmpty {
                Text(emptyHint)
                    .font(DreamTypography.callout)
                    .foregroundStyle(DreamTheme.tertiaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.04)))
            } else {
                ForEach(previewItems) { asset in
                    soundRow(asset)
                }

                if hasMore {
                    Button {
                        expandedLibraryGroup = group
                    } label: {
                        HStack {
                            Text("更多")
                                .font(DreamTypography.callout)
                            Text("共 \(items.count) 项")
                                .font(DreamTypography.caption)
                                .foregroundStyle(DreamTheme.tertiaryText)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(DreamTheme.moonWhite.opacity(0.88))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .dreamRefractiveLiquidGlassRounded(
                            cornerRadius: 14,
                            accent: DreamTheme.mistBlue,
                            intensity: 0.7,
                            interactive: true
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("查看全部\(title)")
                }
            }
        }
    }

    // MARK: - Custom

    private var customContent: some View {
        ScrollView {
            GlassEffectContainer(spacing: 16) {
                VStack(spacing: 14) {
                    customEntryCard(
                        title: "音频上传",
                        subtitle: "点击后可选择现场录音，或直接上传本地文件",
                        symbol: "square.and.arrow.up.on.square.fill",
                        accents: AudioUploadChoice.allCases.map(\.rawValue)
                    ) {
                        showUploadChooser = true
                    }

                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
        }
    }

    private func customEntryCard(
        title: String,
        subtitle: String,
        symbol: String,
        accents: [String],
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: symbol)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(DreamTheme.moonWhite)
                        .frame(width: 52, height: 52)
                        .background {
                            Circle().fill(Color.white.opacity(0.12))
                        }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(DreamTheme.moonWhite)
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(DreamTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DreamTheme.tertiaryText)
                }

                HStack(spacing: 8) {
                    ForEach(accents, id: \.self) { label in
                        Text(label)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(DreamTheme.moonWhite.opacity(0.82))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.white.opacity(0.10)))
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dreamRefractiveLiquidGlassRounded(
                cornerRadius: 22,
                accent: DreamTheme.mistBlue,
                intensity: 0.78,
                interactive: true
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
    }

    // MARK: - Actions

    private func beginRecordUpload() {
        if appState.contentBackendMode == .remote && !appState.isRemoteAuthenticated {
            showLoginHint = true
            return
        }
        showRecordMock = true
    }

    private func beginFileUpload() {
        if canRemoteUpload {
            showFileImporter = true
        } else if appState.contentBackendMode == .remote {
            showLoginHint = true
        } else {
            showUploadMock = true
        }
    }

    private func beginDelete(_ asset: SoundAsset) {
        Task {
            await MainActor.run { isPreparingDelete = true }
            let impact = await appState.fetchSoundDeleteImpact(id: asset.id)
            await MainActor.run {
                isPreparingDelete = false
                deleteImpact = impact
                soundPendingDelete = asset
            }
        }
    }

    private func clearDeletePending() {
        soundPendingDelete = nil
        deleteImpact = nil
    }

    private func handleImportedFiles(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            libraryNotice = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            Task { await uploadRemoteAudio(from: url) }
        }
    }

    @MainActor
    private func uploadRemoteAudio(from fileURL: URL) async {
        guard let remote = appState.remoteLibraryService else {
            libraryNotice = "远程声音库服务不可用"
            return
        }
        let accessed = fileURL.startAccessingSecurityScopedResource()
        defer {
            if accessed { fileURL.stopAccessingSecurityScopedResource() }
        }

        isUploading = true
        defer { isUploading = false }

        do {
            let duration = max(1, Int(try await audioDurationSeconds(of: fileURL).rounded()))
            let filename = fileURL.lastPathComponent
            let name = fileURL.deletingPathExtension().lastPathComponent
            let asset = try await remote.uploadAudio(
                fileURL: fileURL,
                filename: filename,
                contentType: mimeType(for: fileURL),
                kind: .recording,
                name: name.isEmpty ? nil : name,
                durationSeconds: duration
            )
            appState.addSoundAsset(asset)
            section = .existing
            libraryNotice = "已上传「\(asset.name)」"
        } catch {
            libraryNotice = error.localizedDescription
        }
    }

    private func audioDurationSeconds(of url: URL) async throws -> Double {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let seconds = CMTimeGetSeconds(duration)
        return seconds.isFinite ? seconds : 1
    }

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "m4a", "mp4", "aac": return "audio/mp4"
        case "mp3": return "audio/mpeg"
        case "wav": return "audio/wav"
        case "aiff", "aif": return "audio/aiff"
        case "caf": return "audio/x-caf"
        default: return "application/octet-stream"
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
                        assetId: asset.id,
                        layer: asset.kind == .seed ? .voice : .environment
                    )
                )
                appState.selectedTab = .now
            },
            onDelete: { beginDelete(asset) }
        )
    }
}

private struct ExistingLibraryFullList<Row: View>: View {
    let title: String
    let items: [SoundAsset]
    @ViewBuilder var row: (SoundAsset) -> Row
    var onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(items) { asset in
                        row(asset)
                    }
                }
                .padding(20)
                .padding(.bottom, 40)
            }
            .background(DreamTheme.deepBlue.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭", action: onClose)
                }
            }
        }
    }
}

// MARK: - Shared rows

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
                    .font(DreamTypography.cardTitle)
                    .foregroundStyle(DreamTheme.moonWhite)
                Text("\(asset.kind.rawValue) · \(asset.durationText)")
                    .font(DreamTypography.caption)
                    .foregroundStyle(DreamTheme.secondaryText)
            }

            Spacer()

            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 6) {
                    Button(action: onPreview) {
                        Image(systemName: isPreviewing ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DreamTheme.moonWhite)
                            .frame(width: 44, height: 44)
                            .dreamSpatialLiquidGlassCircle(
                                accent: DreamTheme.mistBlue,
                                intensity: isPreviewing ? 0.95 : 0.78
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isPreviewing ? "暂停试听" : "试听")

                    Button(action: onFavorite) {
                        Image(systemName: asset.isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(
                                asset.isFavorite ? DreamTheme.warmApricot : DreamTheme.moonWhite.opacity(0.85)
                            )
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Color.white.opacity(asset.isFavorite ? 0.10 : 0.04)))
                    }
                    .buttonStyle(.plain)
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
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DreamTheme.moonWhite.opacity(0.85))
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Color.white.opacity(0.04)))
                    }
                    .accessibilityLabel("更多操作")
                }
            }
        }
        .padding(14)
        .dreamRefractiveLiquidGlassRounded(
            cornerRadius: 18,
            accent: DreamTheme.mistBlue,
            intensity: 0.58,
            interactive: false
        )
    }
}

struct SoundDetailSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let asset: SoundAsset

    var body: some View {
        ZStack(alignment: .topLeading) {
            DreamTheme.deepBlue
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { dismiss() }

            VStack(alignment: .leading, spacing: 16) {
                Text(asset.name)
                    .font(DreamTypography.pageTitle)
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
                    .font(DreamTypography.callout)
                    .foregroundStyle(DreamTheme.tertiaryText)
                Spacer(minLength: 0)
                    .contentShape(Rectangle())
                    .onTapGesture { dismiss() }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

#Preview {
    SoundLibraryView()
        .environmentObject(AppState())
}
