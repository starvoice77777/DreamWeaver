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
            editorBackground

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    SpatialEditorHeaderMark()
                        .frame(maxWidth: .infinity)
                    sceneSummary
                    soundFieldSection
                    sourceStrip
                    PlaybackControlView(viewModel: viewModel)
                    advancedEditorToggle
                    if showsAdvancedEditor {
                        VStack(spacing: 16) {
                            timelineSection
                            textEditorSection
                        }
                        .transition(
                            .opacity.combined(
                                with: .scale(scale: 0.985, anchor: .top)
                            )
                        )
                    }
                    Spacer(minLength: 28)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, isCreateTabRoot ? 112 : 20)
            }
            .overlay(alignment: .top) {
                editorHeader
                    .frame(height: 46)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
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
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 24)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
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

    private var editorBackground: some View {
        SceneAdaptiveBackground(palette: appState.currentScene.palette)
    }

    private var editorHeader: some View {
        HStack {
            Button {
                if let onResetRequested {
                    onResetRequested()
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: onResetRequested == nil ? "chevron.left" : "arrow.counterclockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(sceneAccent)
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(onResetRequested == nil ? "返回创建" : "重置创作")

            Spacer()

            Button {
                showSaveChooser = true
            } label: {
                Group {
                    if isSaving {
                        ProgressView()
                            .tint(sceneAccent)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(sceneAccent)
                    }
                }
                .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
            .disabled(isSaving)
            .accessibilityLabel("保存场景")
            .accessibilityHint("可选择保存为草稿或个人场景")
        }
        .frame(maxWidth: .infinity)
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

    private var sceneSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(
                "",
                text: $viewModel.sceneName,
                prompt: Text("给这个场景起个名字")
                    .foregroundStyle(DreamTheme.tertiaryText)
            )
            .font(.system(size: 22, weight: .medium, design: .rounded))
            .foregroundStyle(DreamTheme.moonWhite)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.done)

            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(height: 0.7)
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 2)
    }

    private var soundFieldSection: some View {
        VStack(spacing: 10) {
            SpatialCanvasView(viewModel: viewModel)
                .frame(maxWidth: 350)
                .frame(maxWidth: .infinity)

        }
    }

    private var timelineSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 7) {
                ForEach(SpatialTimelineEditMode.allCases) { mode in
                    timelineModeButton(mode)
                }
            }
            .padding(4)
            .background {
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.24))
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.07), lineWidth: 0.7)
                    }
            }

            if viewModel.timelineEditMode == .spatialTrajectory {
                trajectoryRecordingBar
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            TimelineEditorView(viewModel: viewModel)
        }
    }

    private func timelineModeButton(_ mode: SpatialTimelineEditMode) -> some View {
        let isSelected = viewModel.timelineEditMode == mode

        return Button {
            viewModel.setTimelineEditMode(mode)
        } label: {
            Label(mode.title, systemImage: mode.iconName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(
                    isSelected ? DreamTheme.moonWhite : DreamTheme.secondaryText
                )
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background {
                    Capsule(style: .continuous)
                        .fill(
                            isSelected
                                ? sceneAccent.opacity(0.18)
                                : Color.clear
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
                        .font(.system(size: 12, weight: .semibold))
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
                    Text(
                        viewModel.isRecordingTrajectory
                            ? "结束"
                            : (viewModel.isTrajectoryRecordingArmed ? "取消" : "录制")
                    )
                }
                .font(.system(size: 11, weight: .semibold))
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
                Label(
                    SpatialTimeText.string(viewModel.currentTime),
                    systemImage: "clock"
                )
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(DreamTheme.secondaryText)

                Spacer(minLength: 4)

                Button {
                    viewModel.addTextCue()
                } label: {
                    Label("添加到当前时间", systemImage: "plus")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DreamTheme.moonWhite)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .dreamRefractiveLiquidGlassCapsule(
                            accent: sceneAccent,
                            intensity: 0.62,
                            interactive: true
                        )
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
                    .font(.system(size: 11, weight: .medium))
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

    private var sourceStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    showsSoundTray = true
                } label: {
                    Label("添加声音", systemImage: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(sceneAccent)
                        .padding(.horizontal, 13)
                        .frame(height: 40)
                        .background {
                            Capsule(style: .continuous)
                                .fill(sceneAccent.opacity(0.13))
                        }
                }
                .buttonStyle(.plain)

                ForEach(viewModel.soundSources) { source in
                    sourceStripButton(source)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }

    private func sourceStripButton(_ source: SpatialEditorSource) -> some View {
        let isSelected = viewModel.selectedSourceID == source.id

        return Button {
            viewModel.selectSource(source.id)
        } label: {
            HStack(spacing: 7) {
                Image(systemName: source.iconName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(source.themeColor)
                    .frame(width: 25, height: 25)
                    .background {
                        Circle().fill(source.themeColor.opacity(0.12))
                    }

                Text(source.name)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(
                        isSelected
                            ? DreamTheme.moonWhite
                            : DreamTheme.secondaryText
                    )
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .frame(height: 40)
            .background {
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(isSelected ? 0.09 : 0.035))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(source.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var advancedEditorToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.22)) {
                showsAdvancedEditor.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(sceneAccent.opacity(0.86))

                Text("高级编排")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DreamTheme.moonWhite.opacity(0.86))

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DreamTheme.tertiaryText)
                    .rotationEffect(.degrees(showsAdvancedEditor ? 180 : 0))
            }
            .padding(.horizontal, 13)
            .frame(height: 42)
            .background {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.white.opacity(0.035))
            }
        }
        .buttonStyle(.plain)
        .accessibilityValue(showsAdvancedEditor ? "已展开" : "已收起")
    }

    private var editorMaterials: [SpatialEditorMaterial] {
        let libraryMaterials = appState.soundAssets
            .filter { $0.processingStatus == .ready }
            .map { SpatialEditorMaterial.from($0) }
        return viewModel.availableMaterials + libraryMaterials
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
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DreamTheme.secondaryText)
                        .frame(width: 34, height: 34)
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
                HStack(spacing: 28) {
                    if let onExistingSceneRequested {
                        soundTrayUtilityButton(
                            title: "场景",
                            symbol: "square.stack.3d.up.fill"
                        ) {
                            closeSoundTray(then: onExistingSceneRequested)
                        }
                    }
                    if let onCreateSoundRequested {
                        soundTrayUtilityButton(
                            title: "录制",
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

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(editorMaterials) { material in
                        soundTrayRow(material)
                        if material.id != editorMaterials.last?.id {
                            Divider()
                                .overlay(Color.white.opacity(0.055))
                                .padding(.leading, 58)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
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
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(DreamTheme.moonWhite.opacity(0.86))
                    .frame(width: 40, height: 40)
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

    private func soundTrayRow(_ material: SpatialEditorMaterial) -> some View {
        let inUse = viewModel.isMaterialInUse(material)

        return Button {
            viewModel.addMaterial(material)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: material.iconName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(material.themeColor)
                    .frame(width: 36, height: 36)
                    .background {
                        Circle().fill(material.themeColor.opacity(0.11))
                    }

                Text(material.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DreamTheme.moonWhite.opacity(0.90))
                    .lineLimit(1)

                Spacer()

                Image(systemName: inUse ? "checkmark" : "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(
                        inUse ? material.themeColor : DreamTheme.tertiaryText
                    )
                    .frame(width: 28, height: 28)
            }
            .frame(minHeight: 56)
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

private struct SpatialEditorHeaderMark: View {
    @Environment(\.sceneAdaptiveAccent) private var sceneAccent

    var body: some View {
        ZStack {
            ForEach(DreamWeaverMarkStroke.allCases) { stroke in
                DreamWeaverMarkPath(stroke: stroke)
                    .stroke(
                        LinearGradient(
                            colors: [
                                DreamTheme.moonWhite.opacity(0.96),
                                sceneAccent,
                                sceneAccent.opacity(0.78)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(
                            lineWidth: 3.2,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
            }
        }
        .frame(width: 27, height: 46)
        .shadow(color: sceneAccent.opacity(0.26), radius: 4, y: 1)
        .accessibilityElement()
        .accessibilityLabel("DreamWeaver")
    }
}

struct PlaybackControlView: View {
    @ObservedObject var viewModel: SpatialTimelineViewModel
    @Environment(\.sceneAdaptiveAccent) private var sceneAccent

    var body: some View {
        HStack(spacing: 13) {
            Button {
                viewModel.togglePlayback()
            } label: {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(sceneAccent)
                    .frame(width: 40, height: 40)
                    .background {
                        Circle()
                            .fill(
                                sceneAccent.opacity(
                                    viewModel.isPlaying ? 0.17 : 0.10
                                )
                            )
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(viewModel.isPlaying ? "暂停" : "播放")

            VStack(spacing: 7) {
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

                HStack {
                    Text(SpatialTimeText.string(viewModel.currentTime))
                    Spacer()
                    Text(SpatialTimeText.string(viewModel.duration))
                }
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(DreamTheme.tertiaryText)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
    }
}

#Preview {
    SpatialEditorView()
        .environmentObject(AppState())
}
