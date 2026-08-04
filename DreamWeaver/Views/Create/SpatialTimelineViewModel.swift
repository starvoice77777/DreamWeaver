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

    private let seedSourceSceneID: UUID?
    private var playbackTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?

    var isFromExistingScene: Bool { seedSourceSceneID != nil }

    init(seed providedSeed: SpatialEditorSeed? = nil) {
        let seed = providedSeed ?? .blank
        self.sceneName = seed.sceneName
        self.soundSources = seed.soundSources
        self.selectedSourceID = seed.soundSources.first?.id
        self.sourceSceneSubtitle = seed.sourceSceneSubtitle
        self.seedSourceSceneID = seed.sourceSceneID
        self.showsFirstUseHint = seed.soundSources.isEmpty
    }

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
        if radius > 1.02 {
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

    func saveDemoDraft() {
        pause()
        if trimmedSceneName.isEmpty {
            showToast("请先填写场景名称")
            return
        }
        showToast("「\(displaySceneName)」草稿已保存")
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
        toastTask?.cancel()
    }

    private func sortKeyPoints(sourceIndex: Int) {
        soundSources[sourceIndex].keyPoints.sort { $0.time < $1.time }
    }
}
