import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

/// First-class「创建」hub — personal scene authorship entry (roadmap §15.1).
struct CreateHubView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var draftStore = CreateDraftStore.shared
    @State private var isScenePickerPresented = false
    @State private var showSoundLibrary = false
    @State private var editorSeed: SpatialEditorSeed?
    @State private var isSpatialEditorPresented = false
    @State private var editorPresentationID = UUID()
    @State private var showUploadChooser = false
    @State private var showSeedChooser = false
    @State private var showExistingSeedPicker = false
    @State private var seedLaunch: SeedLaunchSource?
    @State private var showUploadMock = false
    @State private var showRecordMock = false
    @State private var showFileImporter = false
    @State private var isUploading = false
    @State private var creationNotice: String?
    @State private var showLoginHint = false
    @State private var isOpeningRemoteDraft = false

    private var materialAssets: [SoundAsset] {
        appState.soundAssets.filter { $0.kind == .recording || $0.kind == .community }
    }

    private var canRemoteUpload: Bool {
        appState.contentBackendMode == .remote
            && appState.isRemoteAuthenticated
            && appState.remoteLibraryService != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        SectionHeader(title: "创建")
                            .padding(.top, 12)

                        Text("把场景与声音统一收进你的创作空间。")
                            .font(DreamTypography.body)
                            .foregroundStyle(DreamTheme.secondaryText)

                        creationSectionTitle("场景", subtitle: "编排画面、声音与空间轨迹")

                        VStack(spacing: 14) {
                            createActionCard(
                                title: "从空白开始",
                                subtitle: "选择画面气质、放入声音，再保存为个人场景",
                                symbol: "sparkles",
                                accent: DreamTheme.warmApricot
                            ) {
                                openEditor(with: .blank)
                            }

                            createActionCard(
                                title: "从已有场景创建",
                                subtitle: "挑选一个已有场景作为底稿，改完后另存为个人场景",
                                symbol: "slider.horizontal.3",
                                accent: DreamTheme.warmApricot
                            ) {
                                isScenePickerPresented = true
                            }
                        }

                        if !draftStore.drafts.isEmpty {
                            draftSection
                        }

                        if appState.isRemoteAuthenticated, !remoteOnlySummaries.isEmpty {
                            remoteDraftSection
                        }

                        creationSectionTitle("声音", subtitle: "录制、上传或生成可用于场景的声音")

                        VStack(spacing: 14) {
                            createActionCard(
                                title: "录制或上传声音",
                                subtitle: "现场录音，或从本地选择音频文件加入声音库",
                                symbol: "waveform.badge.plus",
                                accent: DreamTheme.mistBlue
                            ) {
                                showUploadChooser = true
                            }

                            createActionCard(
                                title: "创建声音种子",
                                subtitle: "使用已有素材、上传文件或现场录音创建陪伴声音",
                                symbol: "leaf.fill",
                                accent: DreamTheme.softLavender
                            ) {
                                showSeedChooser = true
                            }

                            createActionCard(
                                title: "管理已有声音",
                                subtitle: "试听、收藏、重命名或删除已有的声音素材",
                                symbol: "waveform.circle",
                                accent: DreamTheme.mistBlue
                            ) {
                                showSoundLibrary = true
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 120)
                }

                if isUploading {
                    Color.black.opacity(0.35).ignoresSafeArea()
                    ProgressView("正在上传…")
                        .padding(20)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(DreamTheme.moonWhite)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(DreamTheme.backgroundGradient.ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(isPresented: $isScenePickerPresented) {
                CreateScenePickerView { scene in
                    isScenePickerPresented = false
                    // Allow the picker sheet to dismiss before presenting the editor.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        openEditor(with: .from(scene: scene))
                    }
                }
                .environmentObject(appState)
            }
            .fullScreenCover(isPresented: $isSpatialEditorPresented) {
                SpatialEditorView(seed: editorSeed ?? .blank)
                    .id(editorPresentationID)
                    .environmentObject(appState)
            }
            .fullScreenCover(isPresented: $showSoundLibrary) {
                SoundLibraryView(
                    title: "管理已有声音",
                    onCreateRequested: { showSoundLibrary = false },
                    onDismiss: { showSoundLibrary = false }
                )
                .environmentObject(appState)
            }
            .fullScreenCover(item: $seedLaunch) { launch in
                SeedCreationFlow(launchSource: launch)
                    .environmentObject(appState)
            }
            .sheet(isPresented: $showExistingSeedPicker) {
                CreateExistingSoundPicker(
                    assets: materialAssets,
                    onSelect: { asset in
                        showExistingSeedPicker = false
                        openSeedFlow(.existing(asset))
                    }
                )
                .presentationDetents([.medium, .large])
            }
            .confirmationDialog("创建声音", isPresented: $showUploadChooser, titleVisibility: .visible) {
                Button("现场录音") { beginRecordUpload() }
                Button("上传文件") { beginFileUpload() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("选择录音或直接上传本地音频文件。")
            }
            .confirmationDialog("创建声音种子", isPresented: $showSeedChooser, titleVisibility: .visible) {
                Button("已有素材") { showExistingSeedPicker = true }
                Button("上传文件") { openSeedFlow(.file) }
                Button("现场录音") { openSeedFlow(.record) }
                Button("取消", role: .cancel) {}
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: Self.uploadContentTypes,
                allowsMultipleSelection: false
            ) { result in
                handleImportedFiles(result)
            }
            .alert("上传本地文件", isPresented: $showUploadMock) {
                Button("选择演示文件") { addMockRecording(isRecorded: false) }
                Button("取消", role: .cancel) {}
            } message: {
                Text("本地演示模式不会读取真实文件。")
            }
            .alert("录制声音", isPresented: $showRecordMock) {
                Button("完成模拟录制") { addMockRecording(isRecorded: true) }
                Button("取消", role: .cancel) {}
            } message: {
                Text("演示模式不会调用麦克风。远程模式下请先上传本地音频文件。")
            }
            .alert("需要登录", isPresented: $showLoginHint) {
                Button("好", role: .cancel) {}
            } message: {
                Text("远程声音创建需要先登录。可在「我的」完成登录。")
            }
            .alert("提示", isPresented: Binding(
                get: { creationNotice != nil },
                set: { if !$0 { creationNotice = nil } }
            )) {
                Button("好", role: .cancel) { creationNotice = nil }
            } message: {
                Text(creationNotice ?? "")
            }

            .overlay {
                if isOpeningRemoteDraft {
                    ProgressView("打开云端草稿…")
                        .padding(20)
                        .dreamRefractiveLiquidGlassRounded(
                            cornerRadius: 18,
                            accent: DreamTheme.warmApricot,
                            intensity: 0.85
                        )
                }
            }
            .task {
                draftStore.reload()
                await appState.refreshPrivateSceneSummaries()
            }
        }
    }

    private static let uploadContentTypes: [UTType] = {
        var types: [UTType] = [.audio, .mp3, .wav, .aiff]
        if let m4a = UTType(filenameExtension: "m4a") { types.append(m4a) }
        if let caf = UTType(filenameExtension: "caf") { types.append(caf) }
        return types
    }()

    private func openEditor(with seed: SpatialEditorSeed) {
        editorSeed = seed
        editorPresentationID = UUID()
        isSpatialEditorPresented = true
    }

    private var remoteOnlySummaries: [APIContentDTO.PrivateSceneSummary] {
        let localPrivateIds = Set(draftStore.drafts.compactMap(\.privateSceneId))
        return appState.privateSceneSummaries.filter { !localPrivateIds.contains($0.id) }
    }

    private var draftSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("我的草稿")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DreamTheme.moonWhite)

            Text("保存在本机；登录远程后还会同步到云端私人场景。")
                .font(.system(size: 12))
                .foregroundStyle(DreamTheme.tertiaryText)

            VStack(spacing: 10) {
                ForEach(draftStore.drafts) { draft in
                    draftRow(draft)
                }
            }
        }
    }

    private var remoteDraftSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("云端私人场景")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DreamTheme.moonWhite)

            Text("其它设备或此前云端保存的草稿，点按可继续编辑。")
                .font(.system(size: 12))
                .foregroundStyle(DreamTheme.tertiaryText)

            VStack(spacing: 10) {
                ForEach(remoteOnlySummaries) { summary in
                    remoteSummaryRow(summary)
                }
            }
        }
    }

    private func draftRow(_ draft: CreateSceneDraft) -> some View {
        Button {
            openEditor(with: .from(draft: draft))
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(DreamTheme.moonWhite)
                    .frame(width: 42, height: 42)
                    .background {
                        Circle().fill(Color.white.opacity(0.12))
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(draft.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(DreamTheme.moonWhite)
                        .lineLimit(1)
                    Text(draftMeta(draft))
                        .font(.system(size: 12))
                        .foregroundStyle(DreamTheme.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DreamTheme.tertiaryText)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dreamRefractiveLiquidGlassRounded(
                cornerRadius: 18,
                accent: DreamTheme.mistBlue,
                intensity: 0.72,
                interactive: true
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                draftStore.delete(id: draft.id)
            } label: {
                Label("删除本机草稿", systemImage: "trash")
            }
        }
        .accessibilityLabel("草稿 \(draft.name)")
    }

    private func remoteSummaryRow(_ summary: APIContentDTO.PrivateSceneSummary) -> some View {
        Button {
            Task { await openRemoteSummary(summary) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "icloud")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(DreamTheme.moonWhite)
                    .frame(width: 42, height: 42)
                    .background {
                        Circle().fill(Color.white.opacity(0.12))
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(DreamTheme.moonWhite)
                        .lineLimit(1)
                    Text(summary.has_saved_version ? "已发布 v\(summary.saved_version)" : "仅草稿")
                        .font(.system(size: 12))
                        .foregroundStyle(DreamTheme.secondaryText)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DreamTheme.tertiaryText)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dreamRefractiveLiquidGlassRounded(
                cornerRadius: 18,
                accent: DreamTheme.mistBlue,
                intensity: 0.72,
                interactive: true
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("云端场景 \(summary.name)")
    }

    private func draftMeta(_ draft: CreateSceneDraft) -> String {
        let trackCount = draft.soundSources.count
        let tracks = trackCount == 0 ? "尚无声源" : "\(trackCount) 条声源"
        let cloud = draft.privateSceneId == nil ? "仅本机" : "已同步云端"
        return "\(tracks) · \(cloud) · \(Self.relativeDate.localizedString(for: draft.updatedAt, relativeTo: Date()))"
    }

    private static let relativeDate: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    private func openRemoteSummary(_ summary: APIContentDTO.PrivateSceneSummary) async {
        isOpeningRemoteDraft = true
        defer { isOpeningRemoteDraft = false }
        do {
            let detail = try await appState.fetchPrivateSceneDetail(id: summary.id)
            var seed = SpatialEditorSeed.from(privateDetail: detail)
            // Keep a stable local draft id if we already mirrored this private scene.
            if let local = draftStore.drafts.first(where: { $0.privateSceneId == summary.id }) {
                seed.draftID = local.id
            } else {
                seed.draftID = UUID()
            }
            openEditor(with: seed)
        } catch {
            appState.lastServiceMessage = error.localizedDescription
        }
    }

    private func createActionCard(
        title: String,
        subtitle: String,
        symbol: String,
        accent: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(DreamTheme.moonWhite)
                    .frame(width: 48, height: 48)
                    .background {
                        Circle().fill(accent.opacity(0.16))
                    }

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(DreamTypography.sectionTitle)
                        .foregroundStyle(DreamTheme.moonWhite)
                    Text(subtitle)
                        .font(DreamTypography.callout)
                        .foregroundStyle(DreamTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DreamTheme.tertiaryText)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.065))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(accent.opacity(0.16), lineWidth: 0.75)
            }
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
    }

    private func creationSectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(DreamTypography.sectionTitle)
                .foregroundStyle(DreamTheme.moonWhite)
            Text(subtitle)
                .font(DreamTypography.caption)
                .foregroundStyle(DreamTheme.tertiaryText)
        }
        .padding(.top, 4)
    }

    private func beginRecordUpload() {
        if appState.contentBackendMode == .remote && !appState.isRemoteAuthenticated {
            showLoginHint = true
        } else {
            showRecordMock = true
        }
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

    private func openSeedFlow(_ source: SeedLaunchSource) {
        if appState.contentBackendMode == .remote && !appState.isRemoteAuthenticated {
            showLoginHint = true
        } else {
            seedLaunch = source
        }
    }

    private func addMockRecording(isRecorded: Bool) {
        let count = materialAssets.filter { $0.kind == .recording }.count + 1
        let asset = SoundAsset(
            id: UUID(),
            name: isRecorded ? "新录音 \(count)" : "本地录音 \(count)",
            kind: .recording,
            durationSeconds: isRecorded ? 72 : 96,
            symbolName: isRecorded ? "mic.fill" : "doc.fill",
            avatarColor: isRecorded ? 0xA8B8D0 : 0x8197B5,
            isFavorite: false,
            relation: nil,
            createdAt: Date(),
            lastUsedAt: Date()
        )
        appState.addSoundAsset(asset)
        creationNotice = "已创建「\(asset.name)」，可在声音库中查看"
    }

    private func handleImportedFiles(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            creationNotice = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            Task { await uploadRemoteAudio(from: url) }
        }
    }

    @MainActor
    private func uploadRemoteAudio(from fileURL: URL) async {
        guard let remote = appState.remoteLibraryService else {
            creationNotice = "远程声音库服务不可用"
            return
        }
        let accessed = fileURL.startAccessingSecurityScopedResource()
        defer { if accessed { fileURL.stopAccessingSecurityScopedResource() } }
        isUploading = true
        defer { isUploading = false }

        do {
            let media = AVURLAsset(url: fileURL)
            let duration = try await media.load(.duration)
            let seconds = CMTimeGetSeconds(duration)
            let durationSeconds = max(1, Int((seconds.isFinite ? seconds : 1).rounded()))
            let name = fileURL.deletingPathExtension().lastPathComponent
            let asset = try await remote.uploadAudio(
                fileURL: fileURL,
                filename: fileURL.lastPathComponent,
                contentType: mimeType(for: fileURL),
                kind: .recording,
                name: name.isEmpty ? nil : name,
                durationSeconds: durationSeconds
            )
            appState.addSoundAsset(asset)
            creationNotice = "已创建「\(asset.name)」，可在声音库中查看"
        } catch {
            creationNotice = error.localizedDescription
        }
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
}

private struct CreateExistingSoundPicker: View {
    @Environment(\.dismiss) private var dismiss
    let assets: [SoundAsset]
    let onSelect: (SoundAsset) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if assets.isEmpty {
                    ContentUnavailableView(
                        "暂无可选素材",
                        systemImage: "tray",
                        description: Text("请先录制或上传一个声音。")
                    )
                } else {
                    List(assets) { asset in
                        Button { onSelect(asset) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: asset.symbolName)
                                    .foregroundStyle(DreamTheme.moonWhite)
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(Color(hex: asset.avatarColor).opacity(0.85)))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(asset.name).foregroundStyle(DreamTheme.moonWhite)
                                    Text(asset.durationText)
                                        .font(.system(size: 12))
                                        .foregroundStyle(DreamTheme.secondaryText)
                                }
                            }
                        }
                        .listRowBackground(Color.white.opacity(0.04))
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(DreamTheme.deepBlue.ignoresSafeArea())
            .navigationTitle("选择已有素材")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    CreateHubView()
        .environmentObject(AppState())
}
