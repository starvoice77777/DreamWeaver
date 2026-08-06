import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

/// Root creation workspace. Entering the Create tab opens a blank editor directly.
struct CreateHubView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.sceneAdaptiveAccent) private var sceneAccent
    @ObservedObject private var draftStore = CreateDraftStore.shared
    @State private var isScenePickerPresented = false
    @State private var showSoundLibrary = false
    @State private var editorSeed: SpatialEditorSeed = .blank
    @State private var editorPresentationID = UUID()
    @State private var showUploadChooser = false
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
        ZStack {
            SpatialEditorView(
                seed: editorSeed,
                isCreateTabRoot: true,
                onResetRequested: { openEditor(with: .blank) },
                onExistingSceneRequested: { isScenePickerPresented = true },
                onCreateSoundRequested: { showUploadChooser = true },
                onManageSoundsRequested: { showSoundLibrary = true },
                onFinished: { openEditor(with: .blank) }
            )
            .id(editorPresentationID)
            .environmentObject(appState)

            if isUploading {
                Color.black.opacity(0.35).ignoresSafeArea()
                ProgressView("正在上传…")
                    .padding(20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(DreamTheme.moonWhite)
            }
        }
        .sheet(isPresented: $isScenePickerPresented) {
            CreateScenePickerView(
                drafts: draftStore.drafts,
                remoteDrafts: remoteOnlySummaries,
                onSelectScene: { scene in
                    isScenePickerPresented = false
                    Task { await openExistingScene(scene) }
                },
                onSelectDraft: { draft in
                    isScenePickerPresented = false
                    openEditor(with: .from(draft: draft))
                },
                onSelectRemoteDraft: { summary in
                    isScenePickerPresented = false
                    Task { await openRemoteSummary(summary) }
                }
            )
            .environmentObject(appState)
        }
        .sheet(isPresented: $showSoundLibrary) {
            SoundLibraryView(
                title: "声音管理",
                onCreateRequested: {
                    showSoundLibrary = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        showUploadChooser = true
                    }
                },
                onDismiss: { showSoundLibrary = false }
            )
            .environmentObject(appState)
            .presentationDetents([.large])
        }
        .confirmationDialog("创建声音", isPresented: $showUploadChooser, titleVisibility: .visible) {
            Button("现场录音") { beginRecordUpload() }
            Button("上传文件") { beginFileUpload() }
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
        }
        .alert("录制声音", isPresented: $showRecordMock) {
            Button("完成模拟录制") { addMockRecording(isRecorded: true) }
            Button("取消", role: .cancel) {}
        }
        .alert("需要登录", isPresented: $showLoginHint) {
            Button("好", role: .cancel) {}
        } message: {
            Text("请先登录。")
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
                ProgressView("正在导入场景…")
                    .padding(20)
                    .dreamRefractiveLiquidGlassRounded(
                        cornerRadius: 18,
                        accent: sceneAccent,
                        intensity: 0.85
                    )
            }
        }
        .task {
            draftStore.reload()
            await appState.refreshPrivateSceneSummaries()
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
    }

    private var remoteOnlySummaries: [APIContentDTO.PrivateSceneSummary] {
        let localPrivateIds = Set(draftStore.drafts.compactMap(\.privateSceneId))
        return appState.privateSceneSummaries.filter { !localPrivateIds.contains($0.id) }
    }

    private func openExistingScene(_ scene: DreamScene) async {
        isOpeningRemoteDraft = true
        defer { isOpeningRemoteDraft = false }
        if let composition = appState.storedSceneCompositionForCreate(sceneId: scene.id) {
            openEditor(with: .from(scene: scene, composition: composition))
            return
        }
        do {
            let timeline = try await appState.fetchSceneTimelineForCreate(sceneId: scene.id)
            openEditor(with: .from(scene: scene, timeline: timeline))
        } catch {
            // A scene without an authored timeline remains usable as a static template.
            appState.lastServiceMessage = "时间线导入失败，已打开静态声源：\(error.localizedDescription)"
            openEditor(with: .from(scene: scene))
        }
    }

    private func openRemoteSummary(_ summary: APIContentDTO.PrivateSceneSummary) async {
        isOpeningRemoteDraft = true
        defer { isOpeningRemoteDraft = false }
        do {
            let detail = try await appState.fetchPrivateSceneDetail(id: summary.id)
            let baseScene: DreamScene?
            if let sourceSceneID = detail.source_scene_id {
                baseScene = try? await appState.fetchSceneForCreate(sceneId: sourceSceneID)
            } else {
                baseScene = nil
            }
            var seed = SpatialEditorSeed.from(privateDetail: detail, baseScene: baseScene)
            // Keep a stable local draft id if we already mirrored this private scene.
            if let local = draftStore.drafts.first(where: { $0.privateSceneId == summary.id }) {
                seed.draftID = local.id
            } else {
                seed.draftID = UUID()
            }
            for index in seed.soundSources.indices {
                guard let assetID = seed.soundSources[index].assetID,
                      let asset = appState.soundAssets.first(where: { $0.id == assetID }) else {
                    continue
                }
                seed.soundSources[index].materialID = "library-\(asset.id.uuidString)"
                seed.soundSources[index].name = asset.name
                seed.soundSources[index].iconName = asset.symbolName
                seed.soundSources[index].resourceName = asset.previewResourceName
                seed.soundSources[index].isVoice = asset.kind == .seed
            }
            openEditor(with: seed)
        } catch {
            appState.lastServiceMessage = error.localizedDescription
        }
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
        creationNotice = "已创建「\(asset.name)」，可直接在下方选择"
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
            creationNotice = "已创建「\(asset.name)」，可直接在下方选择"
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

#Preview {
    CreateHubView()
        .environmentObject(AppState())
}
