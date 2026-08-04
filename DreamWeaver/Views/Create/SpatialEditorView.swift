import SwiftUI

struct SpatialEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: SpatialTimelineViewModel

    init(seed: SpatialEditorSeed? = nil) {
        _viewModel = StateObject(wrappedValue: SpatialTimelineViewModel(seed: seed))
    }

    var body: some View {
        ZStack {
            editorBackground

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    editorHeader
                    sceneSummary
                    soundFieldSection
                    timelineSection
                    textEditorSection
                    materialsDock
                    Spacer(minLength: 28)
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 20)
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
        .onDisappear {
            viewModel.stopForDismissal()
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
                viewModel.saveDemoDraft()
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DreamTheme.warmApricot)
                    .frame(width: 38, height: 38)
                    .dreamSpatialLiquidGlassCircle(
                        accent: DreamTheme.warmApricot,
                        intensity: 0.62
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("确认保存场景")
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
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(DreamTheme.moonWhite)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)

                Text(sceneSummaryCaption)
                .font(.system(size: 11))
                .foregroundStyle(DreamTheme.secondaryText)
            }

            Spacer(minLength: 8)

            Text(SpatialTimeText.string(viewModel.duration))
                .font(.system(size: 11, design: .monospaced))
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

    private var sceneSummaryCaption: String {
        if viewModel.isFromExistingScene {
            let base = viewModel.sourceSceneSubtitle?.isEmpty == false
                ? (viewModel.sourceSceneSubtitle ?? "已有场景底稿")
                : "已有场景底稿"
            return "\(base) · \(viewModel.soundSources.count) 个声源"
        }
        if viewModel.soundSources.isEmpty {
            return "空白场景 · 从下方素材开始添加"
        }
        return "空间轨迹 · \(viewModel.soundSources.count) 个声源"
    }

    private var soundFieldSection: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("声场")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(DreamTheme.warmApricot)
                    Text("空间轨迹")
                        .font(.system(size: 10))
                        .foregroundStyle(DreamTheme.secondaryText)
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

            HStack(spacing: 7) {
                Circle()
                    .fill(viewModel.selectedSource?.themeColor ?? DreamTheme.warmApricot)
                    .frame(width: 5, height: 5)
                Text(
                    viewModel.soundSources.isEmpty
                        ? "从下方选择素材加入声场，再拖动记录空间轨迹。"
                        : viewModel.showsFirstUseHint
                            ? "移动时间指针，再拖动声源记录位置；拖出圆盘可移除。"
                            : "拖动即记录 · 拖出圆盘移除音源"
                )
                .font(.system(size: 10))
                .foregroundStyle(DreamTheme.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .animation(.easeInOut(duration: 0.25), value: viewModel.showsFirstUseHint)
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

            Text(timelineModeHint)
                .font(.system(size: 10))
                .foregroundStyle(DreamTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

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

    private var timelineModeHint: String {
        switch viewModel.timelineEditMode {
        case .audioTiming:
            return "拖动音频片段调整开始时间，拖动两端调整时长；不会改变空间定位点。"
        case .spatialTrajectory:
            return "横条显示当前时间对应的音频部分；拖动声源只记录位置，不改变音频时长。"
        }
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

            Text("在当前时间添加一句文本，添加后仍可直接修改。")
                .font(.system(size: 11))
                .foregroundStyle(DreamTheme.secondaryText)

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

            Text("自然声可同时加入多个；人声在同一场景中只保留一个。")
                .font(.system(size: 11))
                .foregroundStyle(DreamTheme.secondaryText)

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
}
