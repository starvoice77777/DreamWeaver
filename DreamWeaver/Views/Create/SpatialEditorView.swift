import SwiftUI

struct SpatialEditorView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.sceneAdaptiveAccent) private var sceneAccent
    @StateObject private var viewModel: SpatialTimelineViewModel
    @State private var isSaving = false
    @State private var showSaveChooser = false
    @State private var showsSoundTray = false
    @State private var showsAdvancedEditor = false
    private let isCreateTabRoot: Bool
    private let onResetRequested: (() -> Void)?
    private let onExistingSceneRequested: (() -> Void)?
    private let onCreateSoundRequested: (() -> Void)?
    private let onManageSoundsRequested: (() -> Void)?
    private let onFinished: (() -> Void)?

    init(
        seed: SpatialEditorSeed? = nil,
        isCreateTabRoot: Bool = false,
        onResetRequested: (() -> Void)? = nil,
        onExistingSceneRequested: (() -> Void)? = nil,
        onCreateSoundRequested: (() -> Void)? = nil,
        onManageSoundsRequested: (() -> Void)? = nil,
        onFinished: (() -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: SpatialTimelineViewModel(seed: seed))
        self.isCreateTabRoot = isCreateTabRoot
        self.onResetRequested = onResetRequested
        self.onExistingSceneRequested = onExistingSceneRequested
        self.onCreateSoundRequested = onCreateSoundRequested
        self.onManageSoundsRequested = onManageSoundsRequested
        self.onFinished = onFinished
    }

    var body: some View {
        ZStack {
            Color.clear
                .ignoresSafeArea()

            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        soundFieldSection
                        creationControls
                        editorWorkspaceSwitcher
                        if showsAdvancedEditor {
                            VStack(spacing: 16) {
                                timelineSection
                                if viewModel.timelineEditMode == .audioTiming {
                                    textEditorSection
                                }
                            }
                            .transition(
                                .opacity.combined(
                                    with: .scale(scale: 0.985, anchor: .top)
                                )
                            )
                        }
                        Spacer(minLength: 28)
                    }
                    .padding(.horizontal, SpatialDiskLayout.horizontalInset)
                    .padding(
                        .top,
                        SpatialDiskLayout.topPadding(
                            in: proxy.size,
                            minimum: 72
                        )
                    )
                    .padding(.bottom, isCreateTabRoot ? 112 : 20)
                }
                .overlay(alignment: .top) {
                    editorHeader
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                }
            }

            if let toast = viewModel.toastMessage {
                Text(toast)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DreamTheme.moonWhite)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .dreamRefractiveLiquidGlassCapsule(
                        accent: sceneAccent,
                        intensity: 0.82
                    )
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 78)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .allowsHitTesting(false)
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: viewModel.isPlaying) { _, playing in
            // Avoid fighting the Now tab engine while Create preview is audible.
            if playing, appState.isPlaying {
                appState.playback.pause()
                appState.isPlaying = false
            }
        }
        .onDisappear {
            viewModel.stopForDismissal()
        }
        .sheet(isPresented: $showsSoundTray) {
            soundTray
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(appState.currentScene.palette.bottomColor)
        }
        .confirmationDialog("保存场景", isPresented: $showSaveChooser, titleVisibility: .visible) {
            Button("保存为草稿") {
                Task { await saveDraft() }
            }
            Button("保存为个人场景") {
                Task { await saveAsPersonalScene() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("草稿可在创建页继续修改；个人场景会出现在场景库中，可直接播放。")
        }
    }

    private var editorHeader: some View {
        HStack(spacing: 12) {
            editorLeadingControl

            TextField(
                "",
                text: $viewModel.sceneName,
                prompt: Text("未命名场景")
                    .foregroundStyle(DreamTheme.tertiaryText)
            )
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundStyle(DreamTheme.moonWhite)
            .multilineTextAlignment(.center)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.done)
            .lineLimit(1)
            .frame(maxWidth: .infinity)

            Button {
                showSaveChooser = true
            } label: {
                Group {
                    if isSaving {
                        ProgressView()
                            .tint(sceneAccent)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: DreamIconSize.primary, weight: .semibold))
                            .foregroundStyle(sceneAccent)
                    }
                }
                .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(isSaving)
            .accessibilityLabel("保存场景")
            .accessibilityHint("可选择保存为草稿或个人场景")
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var editorLeadingControl: some View {
        if let onResetRequested {
            Menu {
                Button {
                    onResetRequested()
                } label: {
                    Label("从空白重新开始", systemImage: "arrow.counterclockwise")
                }

                if let onExistingSceneRequested {
                    Button {
                        onExistingSceneRequested()
                    } label: {
                        Label("从已有场景创建", systemImage: "square.stack.3d.up.fill")
                    }
                }
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: DreamIconSize.primary, weight: .semibold))
                    .foregroundStyle(sceneAccent)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("选择创建方式")
            .accessibilityHint("可从空白开始或从已有场景创建")
        } else {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: DreamIconSize.primary, weight: .semibold))
                    .foregroundStyle(sceneAccent)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("返回创建")
        }
    }

    @MainActor
    private func saveDraft() async {
        viewModel.pause()
        if viewModel.trimmedSceneName.isEmpty {
            viewModel.showToast("请先填写场景名称")
            return
        }

        isSaving = true
        defer { isSaving = false }

        var draft = viewModel.makeLocalDraft()
        do {
            try CreateDraftStore.shared.upsert(draft)
        } catch {
            viewModel.showToast("本地保存失败：\(error.localizedDescription)")
            return
        }

        let canSyncRemote = appState.contentBackendMode == .remote && appState.isRemoteAuthenticated
        if canSyncRemote {
            guard !viewModel.soundSources.isEmpty else {
                viewModel.showToast("「\(draft.name)」草稿已保存在本机；加入声音后可同步云端")
                return
            }
            do {
                let detail = try await appState.saveCreateCompositionDraft(
                    privateSceneId: viewModel.privateSceneID,
                    name: draft.name,
                    subtitle: viewModel.sourceSceneSubtitle ?? "",
                    sourceSceneId: draft.sourceSceneId,
                    composition: viewModel.makeCompositionDocument()
                )
                viewModel.bindPrivateSceneID(detail.id)
                draft.privateSceneId = detail.id
                draft.updatedAt = Date()
                try? CreateDraftStore.shared.upsert(draft)
                viewModel.showToast("「\(draft.name)」草稿已保存，可继续修改")
            } catch {
                viewModel.showToast("本机草稿已保存；云端同步失败：\(error.localizedDescription)")
            }
        } else {
            viewModel.showToast("「\(draft.name)」草稿已保存，可继续修改")
        }
    }

    @MainActor
    private func saveAsPersonalScene() async {
        viewModel.pause()
        if viewModel.trimmedSceneName.isEmpty {
            viewModel.showToast("请先填写场景名称")
            return
        }
        guard !viewModel.soundSources.isEmpty else {
            viewModel.showToast("请先加入至少一个声音再保存为个人场景")
            return
        }

        isSaving = true
        defer { isSaving = false }

        let baseScene = viewModel.sourceSceneID.flatMap { sourceID in
            appState.scenes.first { $0.id == sourceID }
        }
        do {
            let scene = try appState.saveCreatedScene(
                id: viewModel.personalSceneID,
                name: viewModel.displaySceneName,
                sourceSceneId: viewModel.sourceSceneID,
                soundSources: viewModel.makeSoundSources(baseScene: baseScene),
                composition: viewModel.makeCompositionDocument()
            )
            // Personal scene is published to the library; drop the draft entry.
            CreateDraftStore.shared.delete(id: viewModel.draftID)
            viewModel.showToast("已保存为个人场景「\(scene.name)」")
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 650_000_000)
                if let onFinished {
                    onFinished()
                } else {
                    dismiss()
                }
            }
        } catch {
            viewModel.showToast("保存个人场景失败：\(error.localizedDescription)")
        }
    }

    private var soundFieldSection: some View {
        SpatialCanvasView(viewModel: viewModel)
            .frame(maxWidth: SpatialDiskLayout.maximumDiameter)
            .frame(maxWidth: .infinity)
    }

    private var timelineSection: some View {
        VStack(spacing: 10) {
            if viewModel.timelineEditMode == .spatialTrajectory {
                trajectoryRecordingBar
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            TimelineEditorView(viewModel: viewModel)
        }
    }

    private var trajectoryRecordingBar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(trajectoryRecordingTitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DreamTheme.moonWhite.opacity(0.92))
                    .contentTransition(.numericText())

                if !trajectoryRecordingSubtitle.isEmpty {
                    Text(trajectoryRecordingSubtitle)
                        .font(.system(size: 9))
                        .foregroundStyle(DreamTheme.tertiaryText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 6)

            if viewModel.canUndoTrajectoryRecording && !viewModel.isRecordingTrajectory {
                Button {
                    viewModel.undoLastTrajectoryRecording()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: DreamIconSize.content, weight: .semibold))
                        .foregroundStyle(DreamTheme.secondaryText)
                        .frame(width: 34, height: 34)
                        .background {
                            Circle().fill(Color.white.opacity(0.055))
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("撤销上一段轨迹录制")
            }

            Button {
                viewModel.toggleTrajectoryRecording()
            } label: {
                HStack(spacing: 6) {
                    Image(
                        systemName: viewModel.isRecordingTrajectory
                            ? "stop.fill"
                            : "record.circle"
                    )
                    .font(.system(size: DreamIconSize.content, weight: .semibold))
                    Text(
                        viewModel.isRecordingTrajectory
                            ? "结束"
                            : (viewModel.isTrajectoryRecordingArmed ? "取消" : "录制")
                    )
                    .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(
                    viewModel.isRecordingTrajectory
                        ? Color.white
                        : DreamTheme.moonWhite.opacity(0.92)
                )
                .padding(.horizontal, 13)
                .frame(height: 34)
                .background {
                    Capsule(style: .continuous)
                        .fill(
                            viewModel.isRecordingTrajectory
                                ? Color.red.opacity(0.72)
                                : sceneAccent.opacity(
                                    viewModel.isTrajectoryRecordingArmed ? 0.30 : 0.16
                                )
                        )
                        .overlay {
                            Capsule(style: .continuous)
                                .stroke(
                                    viewModel.isRecordingTrajectory
                                        ? Color.red.opacity(0.92)
                                        : sceneAccent.opacity(0.34),
                                    lineWidth: 0.8
                                )
                        }
                }
            }
            .buttonStyle(.plain)
            .disabled(viewModel.selectedSource == nil && !viewModel.isTrajectoryRecordingArmed)
            .opacity(
                viewModel.selectedSource == nil && !viewModel.isTrajectoryRecordingArmed
                    ? 0.45
                    : 1
            )
            .accessibilityLabel(
                viewModel.isRecordingTrajectory ? "结束轨迹录制" : "准备轨迹录制"
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.20))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            viewModel.isRecordingTrajectory
                                ? Color.red.opacity(0.24)
                                : Color.white.opacity(0.07),
                            lineWidth: 0.7
                        )
                }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isRecordingTrajectory)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isTrajectoryRecordingArmed)
    }

    private var trajectoryRecordingTitle: String {
        if viewModel.isRecordingTrajectory {
            return "录制移动 · \(String(format: "%.1f", viewModel.recordingDuration)) 秒"
        }
        if viewModel.isTrajectoryRecordingArmed {
            return "等待拖动"
        }
        return viewModel.selectedSource.map { "录制 \($0.name)" } ?? "录制移动"
    }

    private var trajectoryRecordingSubtitle: String {
        if viewModel.isTrajectoryRecordingArmed {
            return "拖动音源开始"
        }
        return ""
    }

    private var textEditorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black.opacity(0.22))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.07), lineWidth: 0.7)
                    }

                if viewModel.textDraft.isEmpty {
                    Text("输入旁白或温和提示文本…")
                        .font(.system(size: 13))
                        .foregroundStyle(DreamTheme.tertiaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 13)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $viewModel.textDraft)
                    .font(.system(size: 13))
                    .foregroundStyle(DreamTheme.moonWhite.opacity(0.92))
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
            }
            .frame(minHeight: 86)

            HStack(spacing: 10) {
                HStack(spacing: 5) {
                    Image(systemName: "clock")
                        .font(.system(size: DreamIconSize.compact, weight: .medium))
                    Text(SpatialTimeText.string(viewModel.currentTime))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
                .foregroundStyle(DreamTheme.secondaryText)

                Spacer(minLength: 4)

                Button {
                    viewModel.addTextCue()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: DreamIconSize.compact, weight: .semibold))
                        Text("添加到当前时间")
                            .font(.system(size: 10, weight: .medium))
                    }
                        .foregroundStyle(DreamTheme.moonWhite)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background {
                            Capsule(style: .continuous)
                                .fill(sceneAccent.opacity(0.16))
                                .overlay {
                                    Capsule(style: .continuous)
                                        .strokeBorder(sceneAccent.opacity(0.24), lineWidth: 0.7)
                                }
                        }
                }
                .buttonStyle(.plain)
            }

            if !viewModel.textCues.isEmpty {
                VStack(spacing: 8) {
                    ForEach(viewModel.textCues) { cue in
                        textCueRow(cue)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.20))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(sceneAccent.opacity(0.16), lineWidth: 0.8)
                }
        }
    }

    private func textCueRow(_ cue: SpatialTextCue) -> some View {
        let isSelected = viewModel.selectedTextCueID == cue.id

        return HStack(alignment: .top, spacing: 9) {
            Button {
                viewModel.selectTextCue(cue.id)
            } label: {
                Text(SpatialTimeText.string(cue.time))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(
                        isSelected ? sceneAccent : DreamTheme.secondaryText
                    )
                    .frame(width: 42, height: 28)
                    .background {
                        Capsule()
                            .fill(sceneAccent.opacity(isSelected ? 0.14 : 0.06))
                    }
            }
            .buttonStyle(.plain)
            .accessibilityHint("跳转到该文本时间")

            TextField(
                "输入文本",
                text: Binding(
                    get: { cue.text },
                    set: { viewModel.updateTextCue(cue.id, text: $0) }
                ),
                axis: .vertical
            )
            .font(.system(size: 12))
            .foregroundStyle(DreamTheme.moonWhite.opacity(0.90))
            .lineLimit(1...3)
            .padding(.vertical, 5)

            Button {
                viewModel.deleteTextCue(cue.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: DreamIconSize.compact, weight: .medium))
                    .foregroundStyle(DreamTheme.tertiaryText)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("删除文本")
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    isSelected
                        ? sceneAccent.opacity(0.07)
                        : Color.white.opacity(0.025)
                )
        }
    }

    private var creationControls: some View {
        VStack(spacing: 12) {
            sourceStrip

            HStack(spacing: 8) {
                creationActionButton(
                    symbol: viewModel.isPlaying ? "pause.fill" : "play.fill",
                    accessibilityLabel: viewModel.isPlaying ? "暂停" : "播放",
                    isActive: viewModel.isPlaying
                ) {
                    viewModel.togglePlayback()
                }

                Text(SpatialTimeText.string(viewModel.currentTime))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(DreamTheme.secondaryText)
                    .frame(width: 38, alignment: .leading)

                PlaybackControlView(viewModel: viewModel)

                Text(SpatialTimeText.string(viewModel.duration))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(DreamTheme.tertiaryText)
                    .frame(width: 38, alignment: .trailing)
            }
            .padding(.horizontal, 4)
        }
    }

    private var sourceStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                creationActionButton(
                    symbol: "plus",
                    accessibilityLabel: "添加声音"
                ) {
                    showsSoundTray = true
                }

                ForEach(viewModel.soundSources) { source in
                    sourceStripButton(source)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 3)
        }
        .scrollClipDisabled()
    }

    private func creationActionButton(
        symbol: String,
        accessibilityLabel: String,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: DreamIconSize.primary, weight: .semibold))
                .foregroundStyle(sceneAccent)
                .frame(width: 48, height: 48)
                .background {
                    Circle()
                        .fill(sceneAccent.opacity(isActive ? 0.18 : 0.09))
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func sourceStripButton(_ source: SpatialEditorSource) -> some View {
        let isSelected = viewModel.selectedSourceID == source.id

        return Button {
            viewModel.selectSource(source.id)
        } label: {
            HStack(spacing: 7) {
                Image(systemName: source.iconName)
                    .font(.system(size: DreamIconSize.content, weight: .medium))
                    .foregroundStyle(source.themeColor)
                    .frame(width: 46, height: 46)
                    .background {
                        Circle().fill(source.themeColor.opacity(0.12))
                    }

                if isSelected {
                    Text(source.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DreamTheme.moonWhite)
                        .lineLimit(1)
                        .padding(.trailing, 5)
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }
            .padding(.horizontal, isSelected ? 5 : 0)
            .frame(height: 48)
            .background {
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(isSelected ? 0.075 : 0))
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.18), value: isSelected)
        .accessibilityLabel(source.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var editorWorkspaceSwitcher: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 0.7)

            HStack(spacing: 4) {
                ForEach(
                    [SpatialTimelineEditMode.spatialTrajectory, .audioTiming]
                ) { mode in
                    editorWorkspaceButton(mode)
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        showsAdvancedEditor.toggle()
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: DreamIconSize.compact, weight: .semibold))
                        .foregroundStyle(DreamTheme.tertiaryText)
                        .rotationEffect(.degrees(showsAdvancedEditor ? 180 : 0))
                        .frame(width: 36, height: 52)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showsAdvancedEditor ? "收起编排" : "展开编排")
            }

            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 0.7)
        }
    }

    private func editorWorkspaceButton(_ mode: SpatialTimelineEditMode) -> some View {
        let isSelected = showsAdvancedEditor && viewModel.timelineEditMode == mode

        return Button {
            withAnimation(.easeInOut(duration: 0.22)) {
                if isSelected {
                    showsAdvancedEditor = false
                } else {
                    viewModel.setTimelineEditMode(mode)
                    showsAdvancedEditor = true
                }
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: mode.iconName)
                    .font(.system(size: DreamIconSize.content, weight: .medium))
                Text(mode.title)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
            }
            .foregroundStyle(isSelected ? sceneAccent : DreamTheme.secondaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .overlay(alignment: .bottom) {
                if isSelected {
                    Capsule()
                        .fill(sceneAccent)
                        .frame(width: 42, height: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var editorMaterials: [SpatialEditorMaterial] {
        let libraryMaterials = appState.soundAssets
            .filter { $0.processingStatus == .ready }
            .map { SpatialEditorMaterial.from($0) }
        return viewModel.availableMaterials + libraryMaterials
    }

    private var soundTraySections: [SoundTraySection] {
        SoundTraySection.all.compactMap { section in
            let materials = editorMaterials.filter {
                section.themes.contains($0.theme)
            }
            guard !materials.isEmpty else { return nil }
            return section.with(materials: materials)
        }
    }

    private var soundTray: some View {
        VStack(spacing: 0) {
            HStack {
                Text("添加声音")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(DreamTheme.moonWhite)

                Spacer()

                Button {
                    showsSoundTray = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: DreamIconSize.primary, weight: .semibold))
                        .foregroundStyle(DreamTheme.secondaryText)
                        .frame(width: 44, height: 44)
                        .background {
                            Circle().fill(Color.white.opacity(0.055))
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭")
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            if isCreateTabRoot {
                HStack(spacing: 36) {
                    if let onCreateSoundRequested {
                        soundTrayUtilityButton(
                            title: "录制或上传",
                            symbol: "waveform.badge.plus"
                        ) {
                            closeSoundTray(then: onCreateSoundRequested)
                        }
                    }
                    if let onManageSoundsRequested {
                        soundTrayUtilityButton(
                            title: "管理",
                            symbol: "slider.horizontal.3"
                        ) {
                            closeSoundTray(then: onManageSoundsRequested)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 14)
            }

            Divider()
                .overlay(Color.white.opacity(0.07))

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 24) {
                    ForEach(soundTraySections) { section in
                        soundTraySection(section)
                    }
                }
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
        }
    }

    private func soundTraySection(_ section: SoundTraySection) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: section.symbol)
                .font(.system(size: DreamIconSize.secondary, weight: .medium))
                .foregroundStyle(sceneAccent)
                .frame(width: 30, height: 30)
                .padding(.horizontal, 20)
                .accessibilityLabel(section.title)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(section.materials) { material in
                        soundTrayCard(material)
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollClipDisabled()
        }
    }

    private func soundTrayUtilityButton(
        title: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.system(size: DreamIconSize.secondary, weight: .medium))
                    .foregroundStyle(DreamTheme.moonWhite.opacity(0.86))
                    .frame(width: 44, height: 44)
                    .background {
                        Circle().fill(Color.white.opacity(0.055))
                    }
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DreamTheme.secondaryText)
            }
        }
        .buttonStyle(.plain)
    }

    private func soundTrayCard(_ material: SpatialEditorMaterial) -> some View {
        let inUse = viewModel.isMaterialInUse(material)

        return Button {
            viewModel.addMaterial(material)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: material.iconName)
                    .font(.system(size: DreamIconSize.content, weight: .medium))
                    .foregroundStyle(sceneAccent)
                    .frame(width: 52, height: 52)
                    .background {
                        Circle()
                            .fill(Color.white.opacity(inUse ? 0.12 : 0.055))
                    }
                    .overlay {
                        Circle()
                            .strokeBorder(
                                inUse
                                    ? sceneAccent.opacity(0.48)
                                    : Color.white.opacity(0.055),
                                lineWidth: inUse ? 1.2 : 0.7
                            )
                    }

                Text(material.name)
                    .font(.system(size: 11, weight: inUse ? .semibold : .medium))
                    .foregroundStyle(
                        inUse
                            ? DreamTheme.moonWhite
                            : DreamTheme.secondaryText
                    )
                    .lineLimit(1)
                    .frame(width: 68)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 68)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(material.name)
        .accessibilityHint(inUse ? "已在声场中，点按选中" : "点按加入声场")
        .accessibilityAddTraits(inUse ? .isSelected : [])
    }

    private func closeSoundTray(then action: @escaping () -> Void) {
        showsSoundTray = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(260))
            action()
        }
    }
}

private struct SoundTraySection: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let themes: [SpatialSourceTheme]
    var materials: [SpatialEditorMaterial] = []

    static let all: [SoundTraySection] = [
        SoundTraySection(
            id: "nature",
            title: "自然环境",
            symbol: "leaf.fill",
            themes: [.rain, .wind, .nature, .water, .fire]
        ),
        SoundTraySection(
            id: "music",
            title: "音乐",
            symbol: "music.note",
            themes: [.music]
        ),
        SoundTraySection(
            id: "voice",
            title: "人声",
            symbol: "person.wave.2.fill",
            themes: [.narration]
        ),
        SoundTraySection(
            id: "texture",
            title: "质感与生活",
            symbol: "waveform.path",
            themes: [.texture]
        )
    ]

    func with(materials: [SpatialEditorMaterial]) -> SoundTraySection {
        var copy = self
        copy.materials = materials
        return copy
    }
}

struct PlaybackControlView: View {
    @ObservedObject var viewModel: SpatialTimelineViewModel
    @Environment(\.sceneAdaptiveAccent) private var sceneAccent

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                sceneAccent.opacity(0.72),
                                sceneAccent
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: proxy.size.width
                            * CGFloat(viewModel.currentTime / viewModel.duration)
                    )
            }
        }
        .frame(height: 3)
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
    }
}

#Preview {
    SpatialEditorView()
        .environmentObject(AppState())
}
