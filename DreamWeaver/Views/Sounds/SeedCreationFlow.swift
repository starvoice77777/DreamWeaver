import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

enum SeedLaunchSource: Identifiable, Equatable {
    case record
    case file
    case existing(SoundAsset)

    var id: String {
        switch self {
        case .record: return "record"
        case .file: return "file"
        case .existing(let asset): return "existing-\(asset.id.uuidString)"
        }
    }
}

struct SeedCreationFlow: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var launchSource: SeedLaunchSource = .record

    @State private var step = 0
    @State private var isRecording = false
    @State private var isPaused = false
    @State private var recordSeconds = 0
    @State private var wavePhase = false
    @State private var authorized = false
    @State private var processProgress = 0.0
    @State private var processMessage = "正在整理声音片段"
    @State private var seedName = ""
    @State private var relation: PersonRelation = .family
    @State private var customRelation = ""
    @State private var isPreviewing = false
    @State private var qualityReport: SeedQualityReport?
    @State private var errorMessage: String?
    @State private var activeJobId: UUID?
    @State private var showFileImporter = false
    @State private var showLoginHint = false
    @State private var selectedSourceURL: URL?
    @State private var usedLocalPick = false
    @State private var didApplyLaunchSource = false

    private var needsRemoteLogin: Bool {
        appState.contentBackendMode == .remote && !appState.isRemoteAuthenticated
    }

    private var remoteSeedPipeline: RemoteSeedPipelineService? {
        appState.seedPipeline as? RemoteSeedPipelineService
    }

    private let tips = [
        "选择安静的环境",
        "与手机保持自然距离",
        "使用平稳、清晰的语速",
        "建议录制1至3分钟"
    ]

    private let sampleScript = "夜已经安静下来了。把今天的脚步放慢一点，让呼吸回到很轻的地方。我在这里，陪你一会儿。"

    var body: some View {
        NavigationStack {
            ZStack {
                DreamTheme.backgroundGradient
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        handleBlankTap()
                    }

                Group {
                    switch step {
                    case 0: introStep
                    case 1: tipsStep
                    case 2: recordStep
                    case 3: qualityStep
                    case 4: authStep
                    case 5: processingStep
                    default: completeStep
                    }
                }
                .padding(24)
                .animation(.easeInOut(duration: 0.35), value: step)
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(step == 0 ? "关闭" : "返回") {
                        handleBack()
                    }
                    .foregroundStyle(DreamTheme.moonWhite)
                    .disabled(step >= 5 && step < 6)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: Self.uploadContentTypes,
                allowsMultipleSelection: false
            ) { result in
                handleImportedSource(result)
            }
            .alert("需要登录", isPresented: $showLoginHint) {
                Button("好", role: .cancel) {}
            } message: {
                Text("远程创建声音种子需要先登录（开发登录或 Apple）。可在「我的」完成登录。")
            }
        }
        .interactiveDismissDisabled(step >= 2 && step <= 5)
        .onAppear(perform: applyLaunchSourceIfNeeded)
        .onDisappear {
            stopRecording()
            appState.playback.stopPreview()
            // Keep pending source only while the flow is alive; process clears it after upload.
            if step < 5 {
                remoteSeedPipeline?.clearPendingSource()
            }
        }
    }

    private func applyLaunchSourceIfNeeded() {
        guard !didApplyLaunchSource else { return }
        didApplyLaunchSource = true

        switch launchSource {
        case .record:
            step = 0
        case .file:
            guard ensureRemoteReady() else { return }
            usedLocalPick = true
            showFileImporter = true
        case .existing(let asset):
            guard ensureRemoteReady() else { return }
            usedLocalPick = true
            recordSeconds = max(asset.durationSeconds, 3)
            if seedName.isEmpty {
                seedName = asset.name
            }
            remoteSeedPipeline?.pendingSourceAssetId = asset.id
            remoteSeedPipeline?.pendingSourceFileURL = nil
            remoteSeedPipeline?.pendingSourceFilename = nil
            remoteSeedPipeline?.pendingSourceContentType = nil
            qualityReport = nil
            errorMessage = nil
            step = 3
        }
    }

    private static let uploadContentTypes: [UTType] = {
        var types: [UTType] = [.audio, .mp3, .wav, .aiff]
        if let m4a = UTType(filenameExtension: "m4a") { types.append(m4a) }
        if let caf = UTType(filenameExtension: "caf") { types.append(caf) }
        return types
    }()

    private func handleBlankTap() {
        // Tap empty areas to step back / dismiss, except during processing.
        guard !(step >= 5 && step < 6) else { return }
        handleBack()
    }

    private func handleBack() {
        if step == 0 {
            dismiss()
        } else if step < 5 {
            step -= 1
        } else if step >= 6 {
            dismiss()
        }
    }

    private var navTitle: String {
        switch step {
        case 0: return "声音种子"
        case 1: return "录制准备"
        case 2: return usedLocalPick ? "本地音频" : "模拟录制"
        case 3: return "质量检测"
        case 4: return "授权确认"
        case 5: return "正在准备"
        default: return "完成"
        }
    }

    // MARK: Steps

    private var introStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer().allowsHitTesting(false)
            Text("留下一颗声音种子")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(DreamTheme.moonWhite)
            Text("用一段清晰的录音，为熟悉的声音留下一份温柔的陪伴。")
                .font(.system(size: 16))
                .foregroundStyle(DreamTheme.secondaryText)
            Spacer().allowsHitTesting(false)
            primaryButton("开始录制") {
                guard ensureRemoteReady() else { return }
                usedLocalPick = false
                step = 1
            }
            secondaryButton("从本地选择") {
                guard ensureRemoteReady() else { return }
                showFileImporter = true
            }
            if appState.contentBackendMode == .remote {
                Text(appState.isRemoteAuthenticated
                     ? "已登录：本地音频会作为种子素材上传；麦克风录制仍为演示计时。"
                     : "远程模式需先登录后再创建种子。")
                    .font(.system(size: 12))
                    .foregroundStyle(DreamTheme.tertiaryText)
            }
        }
    }

    private var tipsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("录音建议")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(DreamTheme.moonWhite)

            ForEach(tips, id: \.self) { tip in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(DreamTheme.warmApricot)
                    Text(tip)
                        .foregroundStyle(DreamTheme.secondaryText)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("示例朗读")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DreamTheme.mistBlue)
                Text(sampleScript)
                    .font(.system(size: 15))
                    .foregroundStyle(DreamTheme.moonWhite.opacity(0.88))
                    .padding(16)
                    .dreamGlass(cornerRadius: 16)
            }
            .padding(.top, 8)

            Spacer().allowsHitTesting(false)
            primaryButton("开始") {
                step = 2
                startRecording()
            }
        }
    }

    private var recordStep: some View {
        VStack(spacing: 28) {
            Spacer().allowsHitTesting(false)
            Text(timeText)
                .font(.system(size: 48, weight: .ultraLight, design: .rounded))
                .foregroundStyle(DreamTheme.moonWhite)
                .monospacedDigit()

            WaveformView(active: isRecording && !isPaused, phase: wavePhase)
                .frame(height: 72)
                .padding(.horizontal, 8)

            Text(isPaused ? "已暂停" : (isRecording ? "正在录制（演示计时）" : "准备就绪"))
                .font(.system(size: 14))
                .foregroundStyle(DreamTheme.secondaryText)
            Text("真实麦克风录音待后续接入；当前远程处理在未选本地文件时使用包内占位音。")
                .font(.system(size: 12))
                .foregroundStyle(DreamTheme.tertiaryText)
                .multilineTextAlignment(.center)

            Spacer().allowsHitTesting(false)

            HStack(spacing: 28) {
                circleAction(isPaused ? "继续" : "暂停", isPaused ? "play.fill" : "pause.fill") {
                    isPaused.toggle()
                }
                .disabled(!isRecording)

                circleAction("重录", "arrow.counterclockwise") {
                    recordSeconds = 0
                    isPaused = false
                    isRecording = true
                }

                circleAction("完成", "checkmark") {
                    stopRecording()
                    step = 3
                }
                .disabled(recordSeconds < 3)
            }
        }
        .onAppear {
            if !isRecording { startRecording() }
        }
    }

    private var qualityStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer().allowsHitTesting(false)
            Image(systemName: qualityReport?.passed == true ? "checkmark.seal.fill" : "hourglass")
                .font(.system(size: 44))
                .foregroundStyle(DreamTheme.warmApricot)
                .frame(maxWidth: .infinity)

            Text(qualityReport == nil ? "正在检测录音质量" : "录音质量良好")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(DreamTheme.moonWhite)
                .frame(maxWidth: .infinity)

            qualityRow("清晰度", qualityReport?.clarity ?? "…")
            qualityRow("环境噪声", qualityReport?.noiseLevel ?? "…")
            qualityRow("有效时长", qualityReport.map { "\($0.effectiveDurationSeconds) 秒" } ?? timeText)
            qualityRow("建议", qualityReport?.recommendation ?? "请稍候")

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(.red.opacity(0.85))
            }

            Spacer().allowsHitTesting(false)
            primaryButton("继续") { step = 4 }
                .disabled(qualityReport?.passed != true)
                .opacity(qualityReport?.passed == true ? 1 : 0.45)
            secondaryButton("重新准备") {
                recordSeconds = 0
                qualityReport = nil
                step = 1
            }
        }
        .task {
            do {
                qualityReport = try await appState.seedPipeline.analyze(durationSeconds: max(recordSeconds, 3))
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private var authStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("授权确认")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(DreamTheme.moonWhite)

            Text("请确认声音提供者身份，并确保已获得本人明确授权。声音仅用于为你准备的个人陪伴场景，你可以随时撤销授权。")
                .font(.system(size: 14))
                .foregroundStyle(DreamTheme.secondaryText)

            Toggle(isOn: $authorized) {
                Text("我确认已获得声音提供者的明确授权")
                    .font(.system(size: 14))
                    .foregroundStyle(DreamTheme.moonWhite)
            }
            .tint(DreamTheme.warmApricot)
            .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 8) {
                Label("使用范围：个人助眠与陪伴场景", systemImage: "shield")
                Label("可随时在设置中撤销授权", systemImage: "arrow.uturn.backward")
            }
            .font(.system(size: 13))
            .foregroundStyle(DreamTheme.tertiaryText)

            Spacer().allowsHitTesting(false)
            primaryButton("确认并继续") {
                Task {
                    do {
                        try await appState.seedPipeline.authorize(confirmed: authorized)
                        step = 5
                        runProcessing()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            .disabled(!authorized)
            .opacity(authorized ? 1 : 0.45)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(.red.opacity(0.85))
            }
        }
    }

    private var processingStep: some View {
        VStack(spacing: 24) {
            Spacer().allowsHitTesting(false)
            ProgressView(value: processProgress)
                .tint(DreamTheme.warmApricot)
                .padding(.horizontal, 20)
                .accessibilityLabel("准备进度")

            Text("\(Int(processProgress * 100))%")
                .font(.system(size: 28, weight: .ultraLight))
                .foregroundStyle(DreamTheme.moonWhite)

            Text(processMessage)
                .font(.system(size: 15))
                .foregroundStyle(DreamTheme.secondaryText)

            Spacer().allowsHitTesting(false)
        }
    }

    private var completeStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("声音已准备好")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(DreamTheme.moonWhite)

            TextField("声音名称", text: $seedName)
                .padding(14)
                .dreamGlass(cornerRadius: 14)
                .foregroundStyle(DreamTheme.moonWhite)

            Text("人物关系")
                .font(.system(size: 13))
                .foregroundStyle(DreamTheme.secondaryText)

            HStack(spacing: 8) {
                ForEach(PersonRelation.allCases) { item in
                    CapsuleChip(title: item.rawValue, selected: relation == item) {
                        relation = item
                    }
                }
            }

            if relation == .custom {
                TextField("自定义关系", text: $customRelation)
                    .padding(12)
                    .dreamGlass(cornerRadius: 12)
                    .foregroundStyle(DreamTheme.moonWhite)
            }

            Button {
                isPreviewing.toggle()
                if isPreviewing {
                    appState.playback.preview(resourceName: "voice_phrase_mom")
                } else {
                    appState.playback.stopPreview()
                }
            } label: {
                Label(isPreviewing ? "停止试听" : "试听声音", systemImage: isPreviewing ? "stop.fill" : "play.fill")
                    .foregroundStyle(DreamTheme.moonWhite)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .dreamGlass(cornerRadius: 14)
            }
            .buttonStyle(.plain)

            Spacer().allowsHitTesting(false)

            primaryButton("保存到声音库") {
                save(addToScene: false)
            }
            secondaryButton("添加到当前场景") {
                save(addToScene: true)
            }
            secondaryButton("重新准备") {
                step = 0
                resetFlow()
            }
        }
        .onAppear {
            if seedName.isEmpty {
                seedName = "新的声音种子"
            }
        }
    }

    // MARK: Helpers

    private var timeText: String {
        String(format: "%d:%02d", recordSeconds / 60, recordSeconds % 60)
    }

    private func qualityRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(DreamTheme.secondaryText)
            Spacer().allowsHitTesting(false)
            Text(value).foregroundStyle(DreamTheme.moonWhite)
        }
        .font(.system(size: 14))
        .padding(.vertical, 6)
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(DreamTheme.midnight)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Capsule().fill(DreamTheme.moonWhite.opacity(0.95)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(DreamTheme.moonWhite)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Capsule().stroke(DreamTheme.divider, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func circleAction(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 18))
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color.white.opacity(0.12)))
                Text(title).font(.system(size: 12))
            }
            .foregroundStyle(DreamTheme.moonWhite)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private func ensureRemoteReady() -> Bool {
        guard needsRemoteLogin else { return true }
        showLoginHint = true
        return false
    }

    private func handleImportedSource(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            Task { await ingestPickedAudio(from: url) }
        }
    }

    @MainActor
    private func ingestPickedAudio(from fileURL: URL) async {
        let accessed = fileURL.startAccessingSecurityScopedResource()
        defer {
            if accessed { fileURL.stopAccessingSecurityScopedResource() }
        }
        do {
            let ext = fileURL.pathExtension.isEmpty ? "m4a" : fileURL.pathExtension
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("seed-source-\(UUID().uuidString).\(ext)")
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: fileURL, to: dest)

            let duration = max(1, Int((try await audioDurationSeconds(of: dest)).rounded()))
            selectedSourceURL = dest
            usedLocalPick = true
            recordSeconds = duration
            if seedName.isEmpty {
                seedName = fileURL.deletingPathExtension().lastPathComponent
            }
            syncPendingSourceToRemote()
            qualityReport = nil
            errorMessage = nil
            step = 3
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func syncPendingSourceToRemote() {
        guard let remote = remoteSeedPipeline else { return }
        guard let url = selectedSourceURL else {
            remote.clearPendingSource()
            return
        }
        remote.pendingSourceFileURL = url
        remote.pendingSourceFilename = url.lastPathComponent
        remote.pendingSourceContentType = mimeType(for: url)
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

    private func startRecording() {
        isRecording = true
        isPaused = false
        wavePhase = true
        Task {
            while isRecording {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if !isRecording { break }
                if !isPaused {
                    recordSeconds += 1
                }
            }
        }
    }

    private func stopRecording() {
        isRecording = false
        isPaused = false
    }

    private func runProcessing() {
        processProgress = 0
        processMessage = usedLocalPick ? "正在上传并整理声音片段" : "正在整理声音片段"
        errorMessage = nil
        syncPendingSourceToRemote()
        Task {
            do {
                let job = try await appState.seedPipeline.startProcess(durationSeconds: max(recordSeconds, 3))
                activeJobId = job.id
                var current = job
                while current.status != .completed {
                    current = try await appState.seedPipeline.pollJob(id: job.id)
                    processProgress = current.progress
                    processMessage = current.message
                }
                processProgress = 1
                step = 6
            } catch {
                errorMessage = error.localizedDescription
                processMessage = error.localizedDescription
            }
        }
    }

    private func save(addToScene: Bool) {
        Task {
            do {
                let asset: SoundAsset
                if let jobId = activeJobId {
                    asset = try await appState.seedPipeline.finalize(
                        jobId: jobId,
                        name: seedName.isEmpty ? "新的声音种子" : seedName,
                        relation: relation
                    )
                } else {
                    asset = SoundAsset(
                        id: UUID(),
                        name: seedName.isEmpty ? "新的声音种子" : seedName,
                        kind: .seed,
                        durationSeconds: max(recordSeconds, 60),
                        symbolName: "leaf.fill",
                        avatarColor: 0xD79A72,
                        isFavorite: false,
                        relation: relation,
                        createdAt: Date(),
                        lastUsedAt: Date(),
                        previewResourceName: "voice_phrase_mom",
                        processingStatus: .ready,
                        authorization: VoiceAuthorization(confirmed: true, revocable: true, authorizationId: "auth-local")
                    )
                }
                appState.addSoundAsset(asset)
                if addToScene {
                    if let idx = appState.soundAssets.firstIndex(where: { $0.id == asset.id }) {
                        appState.soundAssets[idx].isFavorite = true
                    }
                    appState.addSource(
                        SoundSource(
                            name: asset.name,
                            symbolName: "person.wave.2.fill",
                            assetId: asset.id,
                            resourceName: asset.previewResourceName,
                            layer: .voice
                        )
                    )
                    appState.selectedTab = .now
                }
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func resetFlow() {
        isRecording = false
        isPaused = false
        recordSeconds = 0
        authorized = false
        processProgress = 0
        seedName = ""
        relation = .family
        isPreviewing = false
        qualityReport = nil
        errorMessage = nil
        activeJobId = nil
        usedLocalPick = false
        if let selectedSourceURL {
            try? FileManager.default.removeItem(at: selectedSourceURL)
        }
        selectedSourceURL = nil
        remoteSeedPipeline?.clearPendingSource()
        appState.playback.stopPreview()
    }
}

struct WaveformView: View {
    var active: Bool
    var phase: Bool

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<28, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(DreamTheme.mistBlue.opacity(active ? 0.85 : 0.3))
                    .frame(width: 4, height: barHeight(i))
                    .animation(
                        active
                            ? .easeInOut(duration: 0.45).repeatForever(autoreverses: true).delay(Double(i) * 0.03)
                            : .default,
                        value: active
                    )
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func barHeight(_ i: Int) -> CGFloat {
        guard active else { return 10 }
        let base = CGFloat(12 + (i % 5) * 8)
        return phase ? base : base * 0.45
    }
}

#Preview {
    SeedCreationFlow()
        .environmentObject(AppState())
}
