import SwiftUI

struct SpatialEditorView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: SpatialTimelineViewModel
    @State private var isSaving = false
    @State private var showSaveChooser = false

    init(seed: SpatialEditorSeed? = nil) {
        _viewModel = StateObject(wrappedValue: SpatialTimelineViewModel(seed: seed))
    }

    var body: some View {
        ZStack {
            editorBackground

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    sceneSummary
                    soundFieldSection
                    timelineSection
                    textEditorSection
                    materialsDock
                    Spacer(minLength: 28)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                editorHeader
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(headerBackground)
            }

            if let toast = viewModel.toastMessage {
                Text(toast)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DreamTheme.moonWhite)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .dreamRefractiveLiquidGlassCapsule(
                        accent: DreamTheme.warmApricot,
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
        ZStack {
            DreamTheme.backgroundGradient
            RadialGradient(
                colors: [
                    DreamTheme.mistBlue.opacity(0.14),
                    Color.clear
                ],
                center: UnitPoint(x: 0.70, y: 0.14),
                startRadius: 0,
                endRadius: 260
            )
            RadialGradient(
                colors: [
                    DreamTheme.warmApricot.opacity(0.08),
                    Color.clear
                ],
                center: UnitPoint(x: 0.16, y: 0.44),
                startRadius: 0,
                endRadius: 220
            )
        }
        .ignoresSafeArea()
    }

    private var editorHeader: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DreamTheme.warmApricot)
                    .frame(width: 38, height: 38)
                    .dreamSpatialLiquidGlassCircle(
                        accent: DreamTheme.warmApricot,
                        intensity: 0.62
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("返回创建")

            Spacer()

            VStack(spacing: 1) {
                Text("DreamWeaver")
                    .font(.system(size: 23, weight: .light, design: .serif))
                    .foregroundStyle(DreamTheme.warmApricot)
                Text("编织你的梦境")
                    .font(.system(size: 9))
                    .tracking(4)
                    .foregroundStyle(DreamTheme.secondaryText)
            }

            Spacer()

            Button {
                showSaveChooser = true
            } label: {
                Group {
                    if isSaving {
                        ProgressView()
                            .tint(DreamTheme.warmApricot)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(DreamTheme.warmApricot)
                    }
                }
                .frame(width: 38, height: 38)
                .dreamSpatialLiquidGlassCircle(
                    accent: DreamTheme.warmApricot,
                    intensity: 0.62
                )
            }
            .buttonStyle(.plain)
            .disabled(isSaving)
            .accessibilityLabel("保存场景")
            .accessibilityHint("可选择保存为草稿或个人场景")
        }
        .frame(maxWidth: .infinity)
    }

    private var headerBackground: some View {
        Rectangle()
            .fill(DreamTheme.midnight.opacity(0.84))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(DreamTheme.chromeStroke.opacity(0.42))
                    .frame(height: 1)
            }
            .ignoresSafeArea(edges: .top)
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
                soundSources: viewModel.makeSoundSources(baseScene: baseScene)
            )
            // Personal scene is published to the library; drop the draft entry.
            CreateDraftStore.shared.delete(id: viewModel.draftID)
            viewModel.showToast("已保存为个人场景「\(scene.name)」")
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 650_000_000)
                dismiss()
            }
        } catch {
            viewModel.showToast("保存个人场景失败：\(error.localizedDescription)")
        }
    }

    private var sceneSummary: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: 0x24354B),
                                Color(hex: 0x0E1725)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "sparkles")
                    .font(.system(size: 21))
                    .foregroundStyle(DreamTheme.warmApricot.opacity(0.88))
                Circle()
                    .stroke(DreamTheme.warmApricot.opacity(0.28), lineWidth: 0.8)
                    .padding(7)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 5) {
                TextField(
                    "",
                    text: $viewModel.sceneName,
                    prompt: Text("填写场景名称")
                        .foregroundStyle(DreamTheme.tertiaryText)
                )
                .font(DreamTypography.cardTitle)
                .foregroundStyle(DreamTheme.moonWhite)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)

            }

            Spacer(minLength: 8)

            Text(SpatialTimeText.string(viewModel.duration))
                .font(DreamTypography.timecode)
                .foregroundStyle(DreamTheme.tertiaryText)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(Color.black.opacity(0.18))
                .overlay {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 0.7)
                }
        }
    }

    private var soundFieldSection: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("声场")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(DreamTheme.warmApricot)
                }

                Spacer()

                Button {
                    viewModel.resetDemo()
                } label: {
                    Label("清空", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DreamTheme.secondaryText)
                        .padding(.horizontal, 11)
                        .frame(height: 29)
                        .dreamRefractiveLiquidGlassCapsule(
                            accent: DreamTheme.warmApricot,
                            intensity: 0.50,
                            interactive: true
                        )
                }
                .buttonStyle(.plain)
            }

            SpatialCanvasView(viewModel: viewModel)
                .frame(maxWidth: 350)
                .frame(maxWidth: .infinity)

        }
    }

    private var timelineSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("场景时间轴")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(DreamTheme.warmApricot)

                Spacer()

                Text(SpatialTimeText.string(viewModel.currentTime))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(DreamTheme.moonWhite)
                    .contentTransition(.numericText())
            }

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

            TimelineEditorView(viewModel: viewModel)

            PlaybackControlView(viewModel: viewModel)
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
                                ? DreamTheme.warmApricot.opacity(0.18)
                                : Color.clear
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var textEditorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("文本编排")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(DreamTheme.warmApricot)

                Spacer()

                Text("\(viewModel.textCues.count) 段")
                    .font(.system(size: 11))
                    .foregroundStyle(DreamTheme.tertiaryText)
            }

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

                if !viewModel.hasVoiceSource {
                    Label("尚未添加人声", systemImage: "person.wave.2")
                        .font(.system(size: 10))
                        .foregroundStyle(DreamTheme.tertiaryText)
                }

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
                            accent: DreamTheme.warmApricot,
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
                        .stroke(DreamTheme.warmApricot.opacity(0.16), lineWidth: 0.8)
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
                        isSelected ? DreamTheme.warmApricot : DreamTheme.secondaryText
                    )
                    .frame(width: 42, height: 28)
                    .background {
                        Capsule()
                            .fill(DreamTheme.warmApricot.opacity(isSelected ? 0.14 : 0.06))
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
                        ? DreamTheme.warmApricot.opacity(0.07)
                        : Color.white.opacity(0.025)
                )
        }
    }

    private var materialsDock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("可用素材")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(DreamTheme.warmApricot)

                Spacer()

                Text("全部 \(viewModel.availableMaterials.count) 项")
                    .font(.system(size: 11))
                    .foregroundStyle(DreamTheme.tertiaryText)
            }

            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: 12),
                    count: 4
                ),
                spacing: 16
            ) {
                ForEach(viewModel.availableMaterials) { material in
                    materialChip(material)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private func materialChip(_ material: SpatialEditorMaterial) -> some View {
        let inUse = viewModel.isMaterialInUse(material.id)

        return Button {
            viewModel.addMaterial(material)
        } label: {
            VStack(spacing: 7) {
                Image(systemName: material.iconName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(material.themeColor)
                    .frame(width: 48, height: 48)
                    .dreamSpatialLiquidGlassCircle(
                        accent: material.themeColor,
                        intensity: inUse ? 0.92 : 0.68
                    )
                    .overlay {
                        if inUse {
                            Circle()
                                .stroke(material.themeColor.opacity(0.85), lineWidth: 1.4)
                        }
                    }

                Text(material.name)
                    .font(.system(size: 10))
                    .foregroundStyle(
                        inUse
                            ? DreamTheme.moonWhite.opacity(0.92)
                            : DreamTheme.secondaryText
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(material.name)
        .accessibilityHint(inUse ? "已在声场中，点按选中" : "点按加入声场")
        .accessibilityAddTraits(inUse ? .isSelected : [])
    }
}

struct PlaybackControlView: View {
    @ObservedObject var viewModel: SpatialTimelineViewModel

    var body: some View {
        HStack(spacing: 13) {
            Button {
                viewModel.togglePlayback()
            } label: {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DreamTheme.warmApricot)
                    .frame(width: 42, height: 42)
                    .dreamSpatialLiquidGlassCircle(
                        accent: DreamTheme.warmApricot,
                        intensity: 0.76
                    )
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
                                        DreamTheme.warmApricot.opacity(0.72),
                                        DreamTheme.warmApricot
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

            Text(viewModel.isPlaying ? "播放中" : "已暂停")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(
                    viewModel.isPlaying
                        ? DreamTheme.warmApricot
                        : DreamTheme.secondaryText
                )
                .frame(width: 44)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.22))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 0.7)
                }
        }
    }
}

#Preview {
    SpatialEditorView()
        .environmentObject(AppState())
}
