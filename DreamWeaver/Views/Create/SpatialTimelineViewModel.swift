import Combine
import SwiftUI

@MainActor
final class SpatialTimelineViewModel: ObservableObject {
    let duration: Double = 120
    let timeSnapTolerance: Double = 0.2
    let minimumAudioDuration: Double = 1

    @Published var currentTime: Double = 0
    @Published private(set) var isPlaying = false
    @Published var sceneName: String = ""
    @Published var timelineEditMode: SpatialTimelineEditMode = .audioTiming
    @Published private(set) var soundSources: [SpatialEditorSource]
    @Published var selectedSourceID: UUID?
    @Published var selectedKeyPointID: UUID?
    @Published private(set) var draggingSourceID: UUID?
    @Published private(set) var dragPositions: [UUID: CGPoint] = [:]
    @Published var textDraft: String = ""
    @Published private(set) var textCues: [SpatialTextCue] = []
    @Published var selectedTextCueID: UUID?
    @Published var showsFirstUseHint = true
    @Published var toastMessage: String?
    @Published private(set) var sourceSceneSubtitle: String?
    /// Stable local draft id (created on first open / first save).
    @Published private(set) var draftID: UUID
    /// Remote private scene id when cloud draft sync succeeded.
    @Published private(set) var privateSceneID: UUID?

    private let seedSourceSceneID: UUID?
    private var playbackTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?
    private let previewPlayback: LocalPlaybackService
    private var previewGraphSignature: String?
    /// Raw normalized pull distance required before a dragged source is removed.
    private let sourceRemovalRadius: CGFloat = 1.28

    var isFromExistingScene: Bool { seedSourceSceneID != nil }

    init(seed providedSeed: SpatialEditorSeed? = nil) {
        let seed = providedSeed ?? .blank
        self.draftID = seed.draftID ?? UUID()
        self.privateSceneID = seed.privateSceneID
        self.sceneName = seed.sceneName
        self.soundSources = seed.soundSources
        self.textCues = seed.textCues
        self.selectedSourceID = seed.soundSources.first?.id
        self.sourceSceneSubtitle = seed.sourceSceneSubtitle
        self.seedSourceSceneID = seed.sourceSceneID
        self.showsFirstUseHint = seed.soundSources.isEmpty
        self.previewPlayback = LocalPlaybackService()
    }

    func bindPrivateSceneID(_ id: UUID?) {
        privateSceneID = id
    }

    func makeLocalDraft() -> CreateSceneDraft {
        CreateSceneDraft(
            id: draftID,
            privateSceneId: privateSceneID,
            name: displaySceneName,
            sourceSceneId: seedSourceSceneID,
            sourceSceneSubtitle: sourceSceneSubtitle,
            soundSources: soundSources,
            textCues: textCues,
            updatedAt: Date()
        )
    }

    func makeCompositionDocument() -> APIContentDTO.SceneComposition {
        SceneCompositionMapper.composition(
            from: soundSources,
            duration: duration,
            textCues: textCues
        )
    }

    /// Stable id used both for local drafts and published personal scenes.
    var personalSceneID: UUID { draftID }

    var sourceSceneID: UUID? { seedSourceSceneID }

    var trimmedSceneName: String {
        sceneName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var displaySceneName: String {
        trimmedSceneName.isEmpty ? "未命名场景" : trimmedSceneName
    }

    var selectedSource: SpatialEditorSource? {
        source(id: selectedSourceID)
    }

    var selectedKeyPoint: SpatialKeyPoint? {
        guard let source = selectedSource,
              let selectedKeyPointID else {
            return nil
        }
        return source.keyPoints.first { $0.id == selectedKeyPointID }
    }

    func source(id: UUID?) -> SpatialEditorSource? {
        guard let id else { return nil }
        return soundSources.first { $0.id == id }
    }

    func position(for source: SpatialEditorSource, at time: Double? = nil) -> CGPoint {
        if let dragging = dragPositions[source.id] {
            return dragging
        }
        return SpatialTrajectory.position(
            at: time ?? currentTime,
            keyPoints: source.keyPoints,
            defaultPosition: source.defaultPosition
        )
    }

    func selectSource(_ sourceID: UUID) {
        selectedSourceID = sourceID
        if source(id: sourceID)?.keyPoints.contains(where: { $0.id == selectedKeyPointID }) != true {
            selectedKeyPointID = nil
        }
    }

    func beginSourceDrag(_ sourceID: UUID) {
        pause()
        selectSource(sourceID)
        timelineEditMode = .spatialTrajectory
        draggingSourceID = sourceID
        if let source = source(id: sourceID),
           let nearby = source.keyPoints.min(by: {
               abs($0.time - currentTime) < abs($1.time - currentTime)
           }),
           abs(nearby.time - currentTime) <= timeSnapTolerance {
            selectedKeyPointID = nearby.id
        } else {
            selectedKeyPointID = nil
        }
    }

    func updateSourceDrag(_ sourceID: UUID, position: CGPoint) {
        guard draggingSourceID == sourceID else { return }
        // Keep the live finger position so the icon can leave the disk while dragging.
        dragPositions[sourceID] = position
    }

    func endSourceDrag(_ sourceID: UUID, position: CGPoint) {
        dragPositions[sourceID] = nil
        draggingSourceID = nil

        let radius = hypot(position.x, position.y)
        if radius > sourceRemovalRadius {
            removeSource(sourceID)
            return
        }

        let clamped = SpatialTrajectory.clampedToUnitCircle(position)
        addOrUpdatePosition(sourceID: sourceID, position: clamped)
        showsFirstUseHint = false
        showToast("已记录 \(SpatialTimeText.string(currentTime)) 的位置")
    }

    func removeSource(_ sourceID: UUID) {
        pause()
        let name = source(id: sourceID)?.name
        withAnimation(.easeOut(duration: 0.28)) {
            soundSources.removeAll { $0.id == sourceID }
            if selectedSourceID == sourceID {
                selectedSourceID = soundSources.first?.id
            }
            selectedKeyPointID = nil
            dragPositions[sourceID] = nil
            if draggingSourceID == sourceID {
                draggingSourceID = nil
            }
        }
        showToast(name.map { "已移除 \($0)" } ?? "音源已移除")
    }

    func addOrUpdatePosition(sourceID: UUID, position: CGPoint) {
        guard let sourceIndex = soundSources.firstIndex(where: { $0.id == sourceID }) else {
            return
        }

        let clamped = SpatialTrajectory.clampedToUnitCircle(position)
        let nearbyIndex = soundSources[sourceIndex].keyPoints.indices.min {
            abs(soundSources[sourceIndex].keyPoints[$0].time - currentTime)
                < abs(soundSources[sourceIndex].keyPoints[$1].time - currentTime)
        }

        if let nearbyIndex,
           abs(soundSources[sourceIndex].keyPoints[nearbyIndex].time - currentTime)
                <= timeSnapTolerance {
            soundSources[sourceIndex].keyPoints[nearbyIndex].position = clamped
            soundSources[sourceIndex].keyPoints[nearbyIndex].createdByUser = true
            selectedKeyPointID = soundSources[sourceIndex].keyPoints[nearbyIndex].id
        } else {
            let point = SpatialKeyPoint(
                time: currentTime,
                position: clamped,
                createdByUser: true
            )
            soundSources[sourceIndex].keyPoints.append(point)
            selectedKeyPointID = point.id
        }

        sortKeyPoints(sourceIndex: sourceIndex)
        selectedSourceID = sourceID
    }

    func selectKeyPoint(sourceID: UUID, keyPointID: UUID) {
        pause()
        guard let source = source(id: sourceID),
              let point = source.keyPoints.first(where: { $0.id == keyPointID }) else {
            return
        }
        selectedSourceID = sourceID
        selectedKeyPointID = keyPointID
        currentTime = point.time
    }

    func moveKeyPointTime(
        sourceID: UUID,
        keyPointID: UUID,
        proposedTime: Double
    ) {
        pause()
        guard let sourceIndex = soundSources.firstIndex(where: { $0.id == sourceID }),
              let pointIndex = soundSources[sourceIndex].keyPoints.firstIndex(where: {
                  $0.id == keyPointID
              }) else {
            return
        }

        let points = soundSources[sourceIndex].keyPoints
        let minimumGap = 0.05
        let lowerBound = pointIndex > 0
            ? points[pointIndex - 1].time + minimumGap
            : 0
        let upperBound = pointIndex < points.count - 1
            ? points[pointIndex + 1].time - minimumGap
            : duration
        let clampedTime = min(max(proposedTime, lowerBound), upperBound)

        soundSources[sourceIndex].keyPoints[pointIndex].time = clampedTime
        selectedSourceID = sourceID
        selectedKeyPointID = keyPointID
        currentTime = clampedTime
        sortKeyPoints(sourceIndex: sourceIndex)
    }

    func deleteKeyPoint(sourceID: UUID, keyPointID: UUID) {
        pause()
        guard let sourceIndex = soundSources.firstIndex(where: { $0.id == sourceID }) else {
            return
        }
        soundSources[sourceIndex].keyPoints.removeAll { $0.id == keyPointID }
        if selectedKeyPointID == keyPointID {
            selectedKeyPointID = nil
        }
        showToast("定位点已删除，路径已重新生成")
    }

    func setTimelineEditMode(_ mode: SpatialTimelineEditMode) {
        withAnimation(.easeInOut(duration: 0.22)) {
            timelineEditMode = mode
            if mode == .audioTiming {
                selectedKeyPointID = nil
            }
        }
    }

    func moveAudioClip(sourceID: UUID, proposedStart: Double) {
        pause()
        guard let index = soundSources.firstIndex(where: { $0.id == sourceID }) else {
            return
        }
        let clipDuration = min(soundSources[index].audioDuration, duration)
        soundSources[index].audioStartTime = min(
            max(proposedStart, 0),
            max(duration - clipDuration, 0)
        )
        soundSources[index].audioDuration = clipDuration
        selectedSourceID = sourceID
        selectedKeyPointID = nil
    }

    func resizeAudioClipStart(
        sourceID: UUID,
        proposedStart: Double,
        fixedEnd: Double
    ) {
        pause()
        guard let index = soundSources.firstIndex(where: { $0.id == sourceID }) else {
            return
        }
        let end = min(max(fixedEnd, minimumAudioDuration), duration)
        let start = min(
            max(proposedStart, 0),
            max(end - minimumAudioDuration, 0)
        )
        soundSources[index].audioStartTime = start
        soundSources[index].audioDuration = end - start
        selectedSourceID = sourceID
        selectedKeyPointID = nil
    }

    func resizeAudioClipEnd(
        sourceID: UUID,
        proposedEnd: Double,
        fixedStart: Double
    ) {
        pause()
        guard let index = soundSources.firstIndex(where: { $0.id == sourceID }) else {
            return
        }
        let start = min(max(fixedStart, 0), duration - minimumAudioDuration)
        let end = min(
            max(proposedEnd, start + minimumAudioDuration),
            duration
        )
        soundSources[index].audioStartTime = start
        soundSources[index].audioDuration = end - start
        selectedSourceID = sourceID
        selectedKeyPointID = nil
    }

    func finishAudioTimingEdit(sourceID: UUID) {
        guard let source = source(id: sourceID) else { return }
        showToast(
            "音频 \(SpatialTimeText.string(source.audioStartTime))"
                + "–\(SpatialTimeText.string(source.audioEndTime))"
        )
    }

    func scrub(to time: Double) {
        pause()
        currentTime = min(max(time, 0), duration)
        selectedKeyPointID = nil
        selectedTextCueID = nil
        syncPreviewAudio(playIfReady: false)
    }

    func addTextCue() {
        pause()
        let text = textDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            showToast("请先输入文本")
            return
        }

        if let nearbyIndex = textCues.indices.min(by: {
            abs(textCues[$0].time - currentTime) < abs(textCues[$1].time - currentTime)
        }),
           abs(textCues[nearbyIndex].time - currentTime) <= timeSnapTolerance {
            textCues[nearbyIndex].text = text
            selectedTextCueID = textCues[nearbyIndex].id
            showToast("已更新 \(SpatialTimeText.string(currentTime)) 的文本")
        } else {
            let cue = SpatialTextCue(time: currentTime, text: text)
            withAnimation(.easeOut(duration: 0.24)) {
                textCues.append(cue)
                textCues.sort { $0.time < $1.time }
                selectedTextCueID = cue.id
            }
            showToast("已添加 \(SpatialTimeText.string(currentTime)) 的文本")
        }
        textDraft = ""
    }

    func selectTextCue(_ cueID: UUID) {
        pause()
        guard let cue = textCues.first(where: { $0.id == cueID }) else { return }
        selectedTextCueID = cueID
        selectedKeyPointID = nil
        currentTime = cue.time
    }

    func updateTextCue(_ cueID: UUID, text: String) {
        guard let index = textCues.firstIndex(where: { $0.id == cueID }) else { return }
        textCues[index].text = text
    }

    func deleteTextCue(_ cueID: UUID) {
        withAnimation(.easeInOut(duration: 0.22)) {
            textCues.removeAll { $0.id == cueID }
            if selectedTextCueID == cueID {
                selectedTextCueID = nil
            }
        }
        showToast("文本已删除")
    }

    func togglePlayback() {
        isPlaying ? pause() : play()
    }

    func play() {
        guard !isPlaying else { return }
        if currentTime >= duration {
            currentTime = 0
        }

        guard syncPreviewAudio(playIfReady: true) else {
            return
        }

        isPlaying = true
        selectedKeyPointID = nil
        selectedTextCueID = nil
        let startedAt = Date()
        let startedTime = currentTime
        playbackTask?.cancel()
        playbackTask = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled, self.isPlaying {
                do {
                    try await Task.sleep(nanoseconds: 16_666_667)
                } catch {
                    return
                }

                let elapsed = Date().timeIntervalSince(startedAt)
                self.currentTime = min(startedTime + elapsed, self.duration)
                self.syncPreviewAudio(playIfReady: true)
                if self.currentTime >= self.duration {
                    self.pause()
                    return
                }
            }
        }
    }

    func pause() {
        isPlaying = false
        playbackTask?.cancel()
        playbackTask = nil
        previewPlayback.pause()
    }

    func resetDemo() {
        pause()
        soundSources = []
        selectedSourceID = nil
        selectedKeyPointID = nil
        selectedTextCueID = nil
        currentTime = 0
        timelineEditMode = .audioTiming
        dragPositions.removeAll()
        textDraft = ""
        textCues = []
        showsFirstUseHint = true
        showToast("已清空场景内容")
    }

    func makeSoundSources(baseScene: DreamScene?) -> [SoundSource] {
        soundSources.map { editorSource in
            let mappedKey = SceneCompositionMapper.resourceKey(for: editorSource)
            let baseSource = baseScene?.soundSources.first(where: {
                $0.name == editorSource.name
                    || $0.symbolName == editorSource.iconName
                    || $0.resourceName == mappedKey
            })
            let point = SpatialTrajectory.position(
                at: 0,
                keyPoints: editorSource.keyPoints,
                defaultPosition: editorSource.defaultPosition
            )
            let radius = min(max(Double(hypot(point.x, point.y)), 0), 1)
            let angle = atan2(Double(point.x), Double(-point.y))
            let layer: AudioLayerKind = {
                if editorSource.isVoice { return .voice }
                if let layer = baseSource?.layer { return layer }
                switch editorSource.materialID {
                case "wind", "bamboo": return .ambience
                case "towel": return .trigger
                default: return .environment
                }
            }()
            let resourceName: String? = {
                if let existing = baseSource?.resourceName { return existing }
                return mappedKey.hasPrefix("create_") ? nil : mappedKey
            }()

            return SoundSource(
                id: editorSource.id,
                name: editorSource.name,
                symbolName: editorSource.iconName,
                isEnabled: true,
                initialEnvelope: 1,
                position: SpatialPosition(angle: angle, radius: radius),
                assetId: baseSource?.assetId,
                resourceName: resourceName,
                layer: layer
            )
        }
    }

    var availableMaterials: [SpatialEditorMaterial] {
        SpatialEditorMaterial.catalog
    }

    func isMaterialInUse(_ materialID: String) -> Bool {
        soundSources.contains { $0.materialID == materialID }
    }

    var hasVoiceSource: Bool {
        soundSources.contains(where: \.isVoice)
    }

    func addMaterial(_ material: SpatialEditorMaterial) {
        pause()
        if let existing = soundSources.first(where: { $0.materialID == material.id }) {
            selectSource(existing.id)
            showToast("已选中 \(material.name)")
            return
        }

        let point = SpatialKeyPoint(
            time: currentTime,
            position: material.defaultPosition,
            createdByUser: true
        )
        let source = SpatialEditorSource(
            materialID: material.id,
            name: material.name,
            iconName: material.iconName,
            theme: material.theme,
            defaultPosition: material.defaultPosition,
            keyPoints: [point],
            audioStartTime: min(currentTime, duration - minimumAudioDuration),
            audioDuration: min(
                30,
                duration - min(currentTime, duration - minimumAudioDuration)
            ),
            isVoice: material.isVoice
        )

        let replacedVoice = material.isVoice && hasVoiceSource
        withAnimation(.easeOut(duration: 0.28)) {
            if material.isVoice {
                soundSources.removeAll(where: \.isVoice)
            }
            soundSources.append(source)
            selectedSourceID = source.id
            selectedKeyPointID = point.id
        }
        if replacedVoice {
            showToast("场景仅保留一个人声，已替换为 \(material.name)")
        } else {
            showToast("已加入 \(material.name)")
        }
    }

    func showToast(_ message: String) {
        toastTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) {
            toastMessage = message
        }
        toastTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: 1_800_000_000)
            } catch {
                return
            }
            guard let self, !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.25)) {
                self.toastMessage = nil
            }
        }
    }

    func stopForDismissal() {
        pause()
        previewPlayback.stop()
        previewGraphSignature = nil
        toastTask?.cancel()
    }

    /// Loads / updates Create preview audio. Returns false when nothing can play.
    @discardableResult
    private func syncPreviewAudio(playIfReady: Bool) -> Bool {
        let sources = SceneCompositionMapper.playbackSources(from: soundSources, at: currentTime)
        guard !sources.isEmpty else {
            if playIfReady {
                showToast("请先加入可播放的材料（雨/风/竹叶/流水等）")
            }
            previewPlayback.pause()
            return false
        }

        let signature = sources
            .map { "\($0.id.uuidString):\($0.resourceName ?? "")" }
            .sorted()
            .joined(separator: "|")

        if previewGraphSignature != signature {
            do {
                try previewPlayback.load(
                    scene: Self.previewHostScene(name: displaySceneName),
                    sources: sources,
                    timeline: nil
                )
                previewGraphSignature = signature
            } catch {
                showToast(error.localizedDescription)
                return false
            }
        } else {
            for source in sources {
                previewPlayback.updateSource(
                    id: source.id,
                    position: source.position,
                    enabled: source.isEnabled
                )
            }
        }

        if playIfReady {
            previewPlayback.play()
            if let message = previewPlayback.lastErrorMessage, !previewPlayback.isPlaying {
                showToast(message)
                return false
            }
        }
        return true
    }

    private static func previewHostScene(name: String) -> DreamScene {
        DreamScene(
            id: UUID(),
            name: name,
            subtitle: "创作预览",
            description: "",
            category: .nature,
            tags: [],
            palette: ScenePalette(top: 0x1A2740, mid: 0x2C3E55, bottom: 0x1B1410, accent: 0xD79A72),
            soundSources: [],
            isFavorite: false,
            isFrequentlyUsed: false,
            listenCount: 0,
            mockListenerCount: 0,
            visualStyle: .warmLamp,
            isDemoPlayable: true
        )
    }

    private func sortKeyPoints(sourceIndex: Int) {
        soundSources[sourceIndex].keyPoints.sort { $0.time < $1.time }
    }
}
