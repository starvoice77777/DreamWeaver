import Combine
import SwiftUI

@MainActor
final class SpatialTimelineViewModel: ObservableObject {
    @Published private(set) var duration: Double
    let timeSnapTolerance: Double = 0.2
    let minimumAudioDuration: Double = 1

    @Published var currentTime: Double = 0
    @Published private(set) var isPlaying = false
    @Published var sceneName: String = ""
    @Published var timelineEditMode: SpatialTimelineEditMode = .audioTiming
    @Published private(set) var sourceGroups: [SpatialEditorSourceGroup]
    @Published private(set) var audioClips: [SpatialEditorAudioClip]
    @Published var selectedSourceID: UUID?
    @Published var selectedAudioClipID: UUID?
    @Published var selectedKeyPointID: UUID?
    @Published var timelineViewport: TimelineViewport
    @Published private(set) var isTimelineViewportInteracting = false
    @Published private(set) var draggingSourceID: UUID?
    @Published private(set) var dragPositions: [UUID: CGPoint] = [:]
    @Published private(set) var armedTrajectorySourceID: UUID?
    @Published private(set) var recordingTrajectorySourceID: UUID?
    @Published private(set) var liveRecordingSamples: [SpatialMotionSample] = []
    @Published private(set) var canUndoTrajectoryRecording = false
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
    private var toastTask: Task<Void, Never>?
    private let previewPlayback: LocalPlaybackService
    private var previewGraphSignature: String?
    private var recordingSourceSnapshot: SpatialEditorSource?
    private var trajectoryUndoState: TrajectoryUndoState?
    private let recordingSampleInterval: Double = 0.05
    /// Raw normalized pull distance required before a dragged source is removed.
    private let sourceRemovalRadius: CGFloat = 1.28

    var isFromExistingScene: Bool { seedSourceSceneID != nil }
    var isTrajectoryRecordingArmed: Bool { armedTrajectorySourceID != nil }
    var isRecordingTrajectory: Bool { recordingTrajectorySourceID != nil }
    /// Compatibility accessor used by the surrounding Create UI. Entries are
    /// now logical groups, not individual audio clips.
    var soundSources: [SpatialEditorSourceGroup] { sourceGroups }
    var sourceGroupRepresentatives: [SpatialEditorSourceGroup] { sourceGroups }
    var visibleSoundSources: [SpatialEditorSource] {
        sourceGroups.filter { group in
            let active = clips(for: group.id).contains {
                currentTime >= $0.startTime && currentTime < $0.endTime
            }
            return active
                || (!isPlaying && selectedSourceID == group.id)
                || recordingTrajectorySourceID == group.id
        }
    }

    var recordingDuration: Double {
        guard let first = liveRecordingSamples.first else { return 0 }
        return max(currentTime - first.time, 0)
    }

    init(seed providedSeed: SpatialEditorSeed? = nil) {
        let seed = providedSeed ?? .blank
        let document: SpatialEditorDocument
        if let clips = seed.audioClips {
            document = SpatialEditorDocument(sourceGroups: seed.soundSources, audioClips: clips)
        } else {
            document = SpatialEditorDocument.migrate(legacySources: seed.soundSources)
        }
        let contentEnd = document.audioClips.map(\.endTime).max() ?? 0
        self.duration = max(seed.durationSeconds ?? max(contentEnd, 120), 1)
        self.timelineViewport = TimelineViewport(
            sceneDuration: max(seed.durationSeconds ?? max(contentEnd, 120), 1)
        )
        self.draftID = seed.draftID ?? UUID()
        self.privateSceneID = seed.privateSceneID
        self.sceneName = seed.sceneName
        self.sourceGroups = document.sourceGroups
        self.audioClips = document.audioClips
        self.textCues = seed.textCues
        self.selectedSourceID = document.sourceGroups.first?.id
        self.sourceSceneSubtitle = seed.sourceSceneSubtitle
        self.seedSourceSceneID = seed.sourceSceneID
        self.showsFirstUseHint = document.sourceGroups.isEmpty
        self.previewPlayback = LocalPlaybackService()
        self.previewPlayback.onRendererStateChange = { [weak self] state in
            guard let self, self.isPlaying else { return }
            self.currentTime = state.time
            self.followPlayheadIfNeeded()
            self.captureRecordingSample(force: false)
            if !state.isPlaying, state.time >= self.duration {
                if self.isRecordingTrajectory {
                    self.finishTrajectoryRecording()
                } else {
                    self.stopTimelinePlayback()
                }
            }
        }
    }

    func bindPrivateSceneID(_ id: UUID?) {
        privateSceneID = id
    }

    func makeLocalDraft() -> CreateSceneDraft {
        CreateSceneDraft(
            schemaVersion: 2,
            id: draftID,
            privateSceneId: privateSceneID,
            name: displaySceneName,
            sourceSceneId: seedSourceSceneID,
            sourceSceneSubtitle: sourceSceneSubtitle,
            soundSources: sourceGroups,
            audioClips: audioClips,
            textCues: textCues,
            durationSeconds: duration,
            updatedAt: Date()
        )
    }

    func makeCompositionDocument() -> APIContentDTO.SceneComposition {
        SceneCompositionMapper.composition(
            from: SpatialEditorDocument(
                sourceGroups: sourceGroups,
                audioClips: audioClips
            ).legacySources(),
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
        return sourceGroups.first { $0.id == id }
    }

    func position(for source: SpatialEditorSource, at time: Double? = nil) -> CGPoint {
        let groupID = source.effectiveSourceGroupID
        if let dragging = dragPositions[groupID] ?? dragPositions[source.id] {
            return dragging
        }
        let plan = ScenePlanCompiler.compile(
            editorSources: compatibilitySources(for: groupID),
            sceneID: draftID,
            duration: duration
        )
        guard let group = plan.sourceGroups.first else {
            return SpatialTrajectory.position(at: time ?? currentTime, source: source)
        }
        let position = SpatialTrajectoryEvaluator.position(
            at: time ?? currentTime,
            keyframes: group.positionKeyframes,
            defaultPosition: group.defaultPosition
        )
        return CGPoint(
            x: sin(position.angle) * position.radius,
            y: -cos(position.angle) * position.radius
        )
    }

    func hasTrajectory(for source: SpatialEditorSource) -> Bool {
        source.keyPoints.count >= 2 || !(source.motionClips ?? []).isEmpty
            || (recordingTrajectorySourceID == source.id && liveRecordingSamples.count >= 2)
    }

    func isSourceGroupSelected(_ source: SpatialEditorSource) -> Bool {
        selectedSourceID == source.id
    }

    func selectSource(_ sourceID: UUID) {
        selectedSourceID = sourceID
        selectedAudioClipID = nil
        if let armedTrajectorySourceID, armedTrajectorySourceID != sourceID {
            self.armedTrajectorySourceID = nil
        }
        if source(id: sourceID)?.keyPoints.contains(where: { $0.id == selectedKeyPointID }) != true {
            selectedKeyPointID = nil
        }
    }

    func beginSourceDrag(_ sourceID: UUID) {
        selectSource(sourceID)
        timelineEditMode = .spatialTrajectory
        draggingSourceID = sourceID
        if armedTrajectorySourceID == sourceID {
            beginTrajectoryRecording(sourceID: sourceID)
            return
        }

        pause()
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
        let groupID = source(id: sourceID)?.effectiveSourceGroupID ?? sourceID
        dragPositions[groupID] = position
        if recordingTrajectorySourceID == sourceID {
            captureRecordingSample(force: false)
            syncPreviewAudio(playIfReady: true, showsEmptyWarning: false)
        }
    }

    func endSourceDrag(_ sourceID: UUID, position: CGPoint) {
        let groupID = source(id: sourceID)?.effectiveSourceGroupID ?? sourceID
        if recordingTrajectorySourceID == sourceID {
            dragPositions[groupID] = SpatialTrajectory.clampedToUnitCircle(position)
            captureRecordingSample(force: true)
            dragPositions[groupID] = nil
            draggingSourceID = nil
            finishTrajectoryRecording()
            return
        }

        dragPositions[groupID] = nil
        draggingSourceID = nil

        let radius = hypot(position.x, position.y)
        if radius > sourceRemovalRadius {
            removeSourceGroup(groupID)
            return
        }

        let clamped = SpatialTrajectory.clampedToUnitCircle(position)
        addOrUpdateGroupPosition(sourceGroupID: groupID, position: clamped)
        showsFirstUseHint = false
        showToast("已记录 \(SpatialTimeText.string(currentTime)) 的位置")
    }

    func toggleTrajectoryRecording() {
        if isRecordingTrajectory {
            finishTrajectoryRecording()
            return
        }
        if armedTrajectorySourceID != nil {
            armedTrajectorySourceID = nil
            showToast("已取消轨迹录制")
            return
        }
        guard let selectedSourceID, source(id: selectedSourceID) != nil else {
            showToast("请先选择一个音源")
            return
        }

        pause()
        timelineEditMode = .spatialTrajectory
        armedTrajectorySourceID = selectedSourceID
        selectedKeyPointID = nil
        showToast("已就绪，拖动音源开始录制")
    }

    func undoLastTrajectoryRecording() {
        pause()
        guard let state = trajectoryUndoState,
              let sourceIndex = sourceGroups.firstIndex(where: { $0.id == state.sourceID }) else {
            return
        }
        withAnimation(.easeInOut(duration: 0.24)) {
            sourceGroups[sourceIndex].keyPoints = state.keyPoints
            sourceGroups[sourceIndex].motionClips = state.motionClips
            selectedSourceID = state.sourceID
            selectedKeyPointID = nil
        }
        trajectoryUndoState = nil
        canUndoTrajectoryRecording = false
        showToast("已撤销上一段轨迹录制")
    }

    private func beginTrajectoryRecording(sourceID: UUID) {
        guard let source = source(id: sourceID) else { return }
        stopTimelinePlayback()
        if currentTime >= duration {
            currentTime = 0
        }
        recordingSourceSnapshot = source
        recordingTrajectorySourceID = sourceID
        armedTrajectorySourceID = nil
        selectedKeyPointID = nil
        let initialPosition = position(for: source, at: currentTime)
        liveRecordingSamples = [
            SpatialMotionSample(time: currentTime, position: initialPosition)
        ]
        startTimelinePlayback(requireAudio: false)
    }

    private func captureRecordingSample(force: Bool) {
        guard let sourceID = recordingTrajectorySourceID,
              let source = source(id: sourceID),
              let position = dragPositions[source.effectiveSourceGroupID] else {
            return
        }

        let sample = SpatialMotionSample(time: currentTime, position: position)
        if let last = liveRecordingSamples.last {
            let elapsed = sample.time - last.time
            if elapsed < 0.01 {
                liveRecordingSamples[liveRecordingSamples.count - 1] = sample
                return
            }
            if !force && elapsed < recordingSampleInterval {
                return
            }
        }
        liveRecordingSamples.append(sample)
    }

    private func finishTrajectoryRecording() {
        guard let sourceID = recordingTrajectorySourceID else {
            stopTimelinePlayback()
            return
        }
        captureRecordingSample(force: true)
        stopTimelinePlayback()

        let rawSamples = liveRecordingSamples
        let finalPosition = rawSamples.last?.position
        let snapshot = recordingSourceSnapshot
        clearActiveRecording()

        guard let sourceIndex = sourceGroups.firstIndex(where: { $0.id == sourceID }),
              let snapshot else {
            return
        }

        let processed = SpatialTrajectory.processedRecordingSamples(rawSamples)
        guard processed.count >= 2,
              let first = processed.first,
              let last = processed.last,
              last.time - first.time >= 0.05 else {
            if let finalPosition {
                let groupID = source(id: sourceID)?.effectiveSourceGroupID ?? sourceID
                addOrUpdateGroupPosition(sourceGroupID: groupID, position: finalPosition)
                showsFirstUseHint = false
                showToast("录制时间较短，已记录当前位置")
            }
            return
        }

        let clip = SpatialMotionClip(samples: processed)
        var clips = clipsReplacingRange(
            in: snapshot.motionClips ?? [],
            with: clip
        )
        clips.sort { $0.startTime < $1.startTime }

        trajectoryUndoState = TrajectoryUndoState(
            sourceID: sourceID,
            keyPoints: snapshot.keyPoints,
            motionClips: snapshot.motionClips
        )
        canUndoTrajectoryRecording = true

        withAnimation(.easeOut(duration: 0.26)) {
            sourceGroups[sourceIndex].keyPoints.removeAll {
                $0.time >= clip.startTime && $0.time <= clip.endTime
            }
            sourceGroups[sourceIndex].motionClips = clips.isEmpty ? nil : clips
            selectedSourceID = sourceID
            selectedKeyPointID = nil
        }
        showsFirstUseHint = false
        showToast(
            "已录制 \(String(format: "%.1f", clip.duration)) 秒轨迹"
                + " · \(clip.samples.count) 个采样点"
        )
    }

    private func clearActiveRecording() {
        recordingTrajectorySourceID = nil
        recordingSourceSnapshot = nil
        liveRecordingSamples = []
        if let draggingSourceID {
            let groupID = source(id: draggingSourceID)?.effectiveSourceGroupID ?? draggingSourceID
            dragPositions[groupID] = nil
        }
    }

    private func clipsReplacingRange(
        in clips: [SpatialMotionClip],
        with replacement: SpatialMotionClip
    ) -> [SpatialMotionClip] {
        var result: [SpatialMotionClip] = []
        for clip in clips {
            if clip.endTime <= replacement.startTime || clip.startTime >= replacement.endTime {
                result.append(clip)
                continue
            }
            if clip.startTime < replacement.startTime,
               let leading = SpatialTrajectory.sliced(
                   clip,
                   from: clip.startTime,
                   through: replacement.startTime
               ) {
                result.append(leading)
            }
            if clip.endTime > replacement.endTime,
               let trailing = SpatialTrajectory.sliced(
                   clip,
                   from: replacement.endTime,
                   through: clip.endTime
               ) {
                result.append(trailing)
            }
        }
        result.append(replacement)
        return result
    }

    func removeSource(_ sourceID: UUID) {
        removeSourceGroup(sourceID)
    }

    private func removeSourceGroup(_ sourceGroupID: UUID) {
        pause()
        let name = source(id: sourceGroupID)?.name
        withAnimation(.easeOut(duration: 0.28)) {
            sourceGroups.removeAll { $0.id == sourceGroupID }
            audioClips.removeAll { $0.sourceGroupID == sourceGroupID }
            if selectedSourceID == sourceGroupID {
                selectedSourceID = sourceGroups.first?.id
            }
            selectedAudioClipID = nil
            selectedKeyPointID = nil
            dragPositions[sourceGroupID] = nil
            if draggingSourceID == sourceGroupID {
                self.draggingSourceID = nil
            }
            if armedTrajectorySourceID == sourceGroupID {
                self.armedTrajectorySourceID = nil
            }
            if recordingTrajectorySourceID == sourceGroupID {
                self.recordingTrajectorySourceID = nil
                liveRecordingSamples = []
                recordingSourceSnapshot = nil
            }
            if trajectoryUndoState?.sourceID == sourceGroupID {
                trajectoryUndoState = nil
                canUndoTrajectoryRecording = false
            }
        }
        showToast(name.map { "已移除 \($0)" } ?? "声源已移除")
    }

    private func addOrUpdateGroupPosition(sourceGroupID: UUID, position: CGPoint) {
        addOrUpdatePosition(sourceID: sourceGroupID, position: position)
        selectedSourceID = sourceGroupID
    }

    func addOrUpdatePosition(sourceID: UUID, position: CGPoint) {
        guard let sourceIndex = sourceGroups.firstIndex(where: { $0.id == sourceID }) else {
            return
        }

        let clamped = SpatialTrajectory.clampedToUnitCircle(position)
        makeRoomForManualPoint(sourceIndex: sourceIndex, at: currentTime)
        let nearbyIndex = sourceGroups[sourceIndex].keyPoints.indices.min {
            abs(sourceGroups[sourceIndex].keyPoints[$0].time - currentTime)
                < abs(sourceGroups[sourceIndex].keyPoints[$1].time - currentTime)
        }

        if let nearbyIndex,
           abs(sourceGroups[sourceIndex].keyPoints[nearbyIndex].time - currentTime)
                <= timeSnapTolerance {
            sourceGroups[sourceIndex].keyPoints[nearbyIndex].position = clamped
            sourceGroups[sourceIndex].keyPoints[nearbyIndex].createdByUser = true
            selectedKeyPointID = sourceGroups[sourceIndex].keyPoints[nearbyIndex].id
        } else {
            let point = SpatialKeyPoint(
                time: currentTime,
                position: clamped,
                createdByUser: true
            )
            sourceGroups[sourceIndex].keyPoints.append(point)
            selectedKeyPointID = point.id
        }

        sortKeyPoints(sourceIndex: sourceIndex)
        selectedSourceID = sourceID
        selectedAudioClipID = nil
    }

    func selectKeyPoint(sourceID: UUID, keyPointID: UUID) {
        pause()
        guard let source = source(id: sourceID),
              let point = source.keyPoints.first(where: { $0.id == keyPointID }) else {
            return
        }
        selectedSourceID = sourceID
        selectedAudioClipID = nil
        selectedKeyPointID = keyPointID
        currentTime = point.time
    }

    func moveKeyPointTime(
        sourceID: UUID,
        keyPointID: UUID,
        proposedTime: Double
    ) {
        pause()
        guard let sourceIndex = sourceGroups.firstIndex(where: { $0.id == sourceID }),
              let pointIndex = sourceGroups[sourceIndex].keyPoints.firstIndex(where: {
                  $0.id == keyPointID
              }) else {
            return
        }

        let points = sourceGroups[sourceIndex].keyPoints
        let minimumGap = 0.05
        let lowerBound = pointIndex > 0
            ? points[pointIndex - 1].time + minimumGap
            : 0
        let upperBound = pointIndex < points.count - 1
            ? points[pointIndex + 1].time - minimumGap
            : duration
        let clampedTime = min(max(proposedTime, lowerBound), upperBound)

        sourceGroups[sourceIndex].keyPoints[pointIndex].time = clampedTime
        selectedSourceID = sourceID
        selectedKeyPointID = keyPointID
        currentTime = clampedTime
        sortKeyPoints(sourceIndex: sourceIndex)
    }

    func deleteKeyPoint(sourceID: UUID, keyPointID: UUID) {
        pause()
        guard let sourceIndex = sourceGroups.firstIndex(where: { $0.id == sourceID }) else {
            return
        }
        sourceGroups[sourceIndex].keyPoints.removeAll { $0.id == keyPointID }
        if selectedKeyPointID == keyPointID {
            selectedKeyPointID = nil
        }
        showToast("定位点已删除，路径已重新生成")
    }

    func setTimelineEditMode(_ mode: SpatialTimelineEditMode) {
        if mode != .spatialTrajectory {
            if isRecordingTrajectory {
                finishTrajectoryRecording()
            }
            armedTrajectorySourceID = nil
        }
        withAnimation(.easeInOut(duration: 0.22)) {
            timelineEditMode = mode
            if mode == .audioTiming {
                selectedKeyPointID = nil
            } else {
                selectedAudioClipID = nil
            }
        }
    }

    func selectAudioClip(_ clipID: UUID) {
        pause()
        guard let clip = clip(id: clipID) else { return }
        selectedSourceID = clip.sourceGroupID
        selectedAudioClipID = clipID
        selectedKeyPointID = nil
    }

    func moveAudioClip(clipID: UUID, proposedStart: Double) {
        pause()
        guard let index = audioClips.firstIndex(where: { $0.id == clipID }) else {
            return
        }
        let item = audioClips[index]
        let neighbors = clipNeighbors(for: item)
        let lower = neighbors.previous?.endTime ?? 0
        let upper = (neighbors.next?.startTime ?? duration) - item.duration
        let snapped = snappedTime(proposedStart, candidates: [lower, upper])
        audioClips[index].startTime = min(max(snapped, lower), max(upper, lower))
        selectedSourceID = item.sourceGroupID
        selectedAudioClipID = clipID
        selectedKeyPointID = nil
    }

    func resizeAudioClipStart(
        clipID: UUID,
        proposedStart: Double,
        fixedEnd: Double
    ) {
        pause()
        guard let index = audioClips.firstIndex(where: { $0.id == clipID }) else {
            return
        }
        let item = audioClips[index]
        let previousEnd = clipNeighbors(for: item).previous?.endTime ?? 0
        let end = min(max(fixedEnd, minimumAudioDuration), duration)
        let proposed = snappedTime(proposedStart, candidates: [previousEnd])
        let start = min(max(proposed, previousEnd), end - minimumAudioDuration)
        audioClips[index].startTime = start
        audioClips[index].duration = end - start
        selectedSourceID = item.sourceGroupID
        selectedAudioClipID = clipID
        selectedKeyPointID = nil
    }

    func resizeAudioClipEnd(
        clipID: UUID,
        proposedEnd: Double,
        fixedStart: Double
    ) {
        pause()
        guard let index = audioClips.firstIndex(where: { $0.id == clipID }) else {
            return
        }
        let item = audioClips[index]
        let nextStart = clipNeighbors(for: item).next?.startTime ?? duration
        let start = min(max(fixedStart, 0), duration - minimumAudioDuration)
        let proposed = snappedTime(proposedEnd, candidates: [nextStart])
        let end = min(max(proposed, start + minimumAudioDuration), nextStart)
        audioClips[index].startTime = start
        audioClips[index].duration = end - start
        selectedSourceID = item.sourceGroupID
        selectedAudioClipID = clipID
        selectedKeyPointID = nil
    }

    func finishAudioTimingEdit(clipID: UUID) {
        guard let clip = clip(id: clipID) else { return }
        showToast(
            "音频 \(SpatialTimeText.string(clip.startTime))"
                + "–\(SpatialTimeText.string(clip.endTime))"
        )
    }

    func deleteAudioClip(_ clipID: UUID) {
        pause()
        guard let item = clip(id: clipID) else { return }
        let groupID = item.sourceGroupID
        withAnimation(.easeInOut(duration: 0.22)) {
            audioClips.removeAll { $0.id == clipID }
            selectedAudioClipID = nil
        }
        if clips(for: groupID).isEmpty {
            removeSourceGroup(groupID)
        } else {
            if let groupIndex = sourceGroups.firstIndex(where: { $0.id == groupID }),
               let first = clips(for: groupID).first {
                sourceGroups[groupIndex].assetID = first.assetID
                sourceGroups[groupIndex].resourceName = first.resourceName
            }
            showToast("音频段已删除")
        }
    }

    func clearTimelineItemSelection() {
        selectedAudioClipID = nil
        selectedKeyPointID = nil
    }

    func scrub(to time: Double) {
        pause()
        currentTime = min(max(time, 0), duration)
        selectedAudioClipID = nil
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
        selectedAudioClipID = nil
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
        startTimelinePlayback(requireAudio: true)
    }

    private func startTimelinePlayback(requireAudio: Bool) {
        guard !isPlaying else { return }
        if currentTime >= duration {
            currentTime = 0
        }

        isPlaying = true
        let audioReady = syncPreviewAudio(
            playIfReady: true,
            showsEmptyWarning: requireAudio
        )
        guard audioReady else {
            isPlaying = false
            return
        }

        selectedKeyPointID = nil
        selectedTextCueID = nil
    }

    func pause() {
        if isRecordingTrajectory {
            finishTrajectoryRecording()
            return
        }
        stopTimelinePlayback()
    }

    private func stopTimelinePlayback() {
        isPlaying = false
        previewPlayback.pause()
    }

    func resetDemo() {
        pause()
        sourceGroups = []
        audioClips = []
        selectedSourceID = nil
        selectedAudioClipID = nil
        selectedKeyPointID = nil
        selectedTextCueID = nil
        currentTime = 0
        duration = 120
        timelineViewport = TimelineViewport(sceneDuration: duration)
        timelineEditMode = .audioTiming
        dragPositions.removeAll()
        armedTrajectorySourceID = nil
        recordingTrajectorySourceID = nil
        liveRecordingSamples = []
        recordingSourceSnapshot = nil
        trajectoryUndoState = nil
        canUndoTrajectoryRecording = false
        textDraft = ""
        textCues = []
        showsFirstUseHint = true
        showToast("已清空场景内容")
    }

    func makeSoundSources(baseScene: DreamScene?) -> [SoundSource] {
        sourceGroupRepresentatives.map { editorSource in
            let firstClip = clips(for: editorSource.id).first
            var compatibilitySource = editorSource
            compatibilitySource.assetID = firstClip?.assetID
            compatibilitySource.resourceName = firstClip?.resourceName
            let mappedKey = SceneCompositionMapper.resourceKey(for: compatibilitySource)
            let baseSource = baseScene?.soundSources.first(where: {
                $0.id == editorSource.effectiveSourceGroupID
                    || $0.name == editorSource.name
                    || $0.symbolName == editorSource.iconName
                    || $0.resourceName == mappedKey
            })
            let point = position(for: editorSource, at: 0)
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
                if let libraryResource = firstClip?.resourceName { return libraryResource }
                if let existing = baseSource?.resourceName { return existing }
                return mappedKey.hasPrefix("create_") ? nil : mappedKey
            }()

            return SoundSource(
                id: editorSource.effectiveSourceGroupID,
                name: baseSource?.name ?? (editorSource.isVoice ? "轻声陪伴" : editorSource.name),
                symbolName: baseSource?.symbolName ?? editorSource.iconName,
                isEnabled: true,
                initialEnvelope: 1,
                position: SpatialPosition(angle: angle, radius: radius),
                assetId: firstClip?.assetID ?? baseSource?.assetId,
                resourceName: resourceName,
                layer: layer
            )
        }
    }

    var availableMaterials: [SpatialEditorMaterial] {
        // The bundled ac_hum recording is neither fire nor loud enough to serve
        // as a useful substitute. Keep fire unavailable until a real asset ships.
        SpatialEditorMaterial.catalog.filter { $0.id != "fire" }
    }

    func isMaterialInUse(_ material: SpatialEditorMaterial) -> Bool {
        sourceGroups.contains { $0.materialID == material.id }
            || audioClips.contains {
                (material.assetID != nil && $0.assetID == material.assetID)
                    || (material.resourceName != nil
                        && $0.resourceName == material.resourceName)
            }
    }

    var hasVoiceSource: Bool {
        sourceGroups.contains(where: \.isVoice)
    }

    func addMaterial(_ material: SpatialEditorMaterial) {
        pause()
        let existing = sourceGroups.first(where: {
            (material.isVoice && $0.isVoice)
                || $0.materialID == material.id
                || (material.assetID != nil && $0.assetID == material.assetID)
                || (material.resourceName != nil && $0.resourceName == material.resourceName)
        })
        let group: SpatialEditorSourceGroup
        if let existing {
            group = existing
        } else {
            let point = SpatialKeyPoint(
                time: currentTime,
                position: material.defaultPosition,
                createdByUser: true
            )
            group = SpatialEditorSource(
                sourceGroupID: nil,
                materialID: material.id,
                assetID: material.assetID,
                resourceName: material.resourceName,
                name: material.name,
                iconName: material.iconName,
                theme: material.theme,
                defaultPosition: material.defaultPosition,
                keyPoints: [point],
                audioStartTime: 0,
                audioDuration: 1,
                isVoice: material.isVoice
            )
        }
        let start = existing.map { clips(for: $0.id).map(\.endTime).max() ?? currentTime }
            ?? currentTime
        let newEnd = start + TimelineViewport.defaultSpan
        if newEnd > duration {
            duration = newEnd
            timelineViewport.clamp(to: duration)
        }
        let clip = SpatialEditorAudioClip(
            sourceGroupID: group.id,
            assetID: material.assetID,
            resourceName: material.resourceName,
            startTime: start,
            duration: TimelineViewport.defaultSpan,
            isLooping: true,
            crossfadeMilliseconds: LoopCrossfadeController.preferredMilliseconds(
                for: material.resourceName ?? SceneCompositionMapper.resourceKey(for: group)
            ),
            isVoicePhrase: material.isVoice
        )
        currentTime = start

        withAnimation(.easeOut(duration: 0.28)) {
            if existing == nil { sourceGroups.append(group) }
            audioClips.append(clip)
            selectedSourceID = group.id
            selectedAudioClipID = clip.id
            selectedKeyPointID = nil
        }
        focusTimeline(on: start, preferredSpan: TimelineViewport.defaultSpan)
        showToast("已加入 \(material.name) · 30 秒")
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
    private func syncPreviewAudio(
        playIfReady: Bool,
        showsEmptyWarning: Bool = true
    ) -> Bool {
        let requestedTime = currentTime
        let plan = ScenePlanCompiler.compile(
            editorSources: SpatialEditorDocument(
                sourceGroups: sourceGroups,
                audioClips: audioClips
            ).legacySources(),
            sceneID: draftID,
            duration: duration
        )
        guard !plan.sourceGroups.isEmpty else {
            if playIfReady && showsEmptyWarning {
                showToast("请先加入可播放的材料（雨/风/竹叶/流水等）")
            }
            previewPlayback.pause()
            return false
        }
        if plan.clips.isEmpty, showsEmptyWarning {
            if playIfReady {
                showToast("当前场景没有可播放的音频片段")
            }
            previewPlayback.pause()
            return false
        }

        let clipSignature = plan.clips
            .map {
                "\($0.id.uuidString):\($0.sourceGroupID.uuidString)"
                    + ":\($0.assetID?.uuidString ?? ""):\($0.resourceKey ?? "")"
                    + ":\($0.startSeconds):\($0.endSeconds):\($0.playbackMode.rawValue)"
                    + ":\($0.sourceOffsetSeconds):\($0.crossfadeMilliseconds)"
                    + ":\($0.fadeInMilliseconds):\($0.fadeOutMilliseconds)"
                    + ":\($0.masteringProfileKey ?? "")"
            }
            .sorted()
            .joined(separator: "|")
        let groupSignature = plan.sourceGroups
            .map { group in
                let frames = group.positionKeyframes.map {
                    "\($0.time),\($0.position.angle),\($0.position.radius),\($0.interpolation.rawValue)"
                }
                .joined(separator: ";")
                return "\(group.id.uuidString):\(frames)"
            }
            .sorted()
            .joined(separator: "|")
        let signature = clipSignature + "#" + groupSignature

        let rebuiltGraph = previewGraphSignature != signature
        if rebuiltGraph {
            do {
                try previewPlayback.load(
                    scene: Self.previewHostScene(name: displaySceneName),
                    plan: plan
                )
                previewGraphSignature = signature
            } catch {
                showToast(error.localizedDescription)
                return false
            }
        } else {
            for source in sourceGroupRepresentatives {
                let point = position(for: source)
                previewPlayback.updateSource(
                    id: source.id,
                    position: SpatialPosition(
                        angle: atan2(point.x, -point.y),
                        radius: min(max(hypot(point.x, point.y), 0), 1)
                    ),
                    enabled: true
                )
            }
        }

        if rebuiltGraph || !playIfReady || !previewPlayback.isPlaying {
            previewPlayback.seek(to: requestedTime)
        }
        if playIfReady {
            previewPlayback.play(allowSilentClock: !showsEmptyWarning)
            if showsEmptyWarning, !previewPlayback.hasPlayableAudio {
                showToast(previewPlayback.lastErrorMessage ?? "当前素材尚不可播放")
                previewPlayback.pause()
                return false
            }
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
            visualStyle: .longRoad,
            isDemoPlayable: true
        )
    }

    func clips(for sourceGroupID: UUID) -> [SpatialEditorAudioClip] {
        audioClips
            .filter { $0.sourceGroupID == sourceGroupID }
            .sorted { lhs, rhs in
                lhs.startTime == rhs.startTime
                    ? lhs.id.uuidString < rhs.id.uuidString
                    : lhs.startTime < rhs.startTime
            }
    }

    func isSourceActive(_ sourceGroupID: UUID, at time: Double? = nil) -> Bool {
        let evaluatedTime = time ?? currentTime
        return clips(for: sourceGroupID).contains {
            evaluatedTime >= $0.startTime && evaluatedTime < $0.endTime
        }
    }

    func clip(id: UUID?) -> SpatialEditorAudioClip? {
        guard let id else { return nil }
        return audioClips.first { $0.id == id }
    }

    func totalActiveDuration(for sourceGroupID: UUID) -> Double {
        clips(for: sourceGroupID).reduce(0) { $0 + $1.duration }
    }

    func automaticBoundaryKeyPoints(
        for sourceGroupID: UUID
    ) -> [SpatialGeneratedBoundaryKeyPoint] {
        guard let group = source(id: sourceGroupID) else { return [] }
        let items = clips(for: sourceGroupID)
        guard items.count > 1 else { return [] }
        let authored = SpatialTrajectory.flattenedKeyPoints(for: group)
            .sorted { $0.time < $1.time }
        var result: [SpatialGeneratedBoundaryKeyPoint] = []

        for index in 0..<(items.count - 1) {
            let previous = items[index]
            let next = items[index + 1]
            guard next.startTime - previous.endTime > 0.001 else { continue }
            let hasExplicitGapPoint = authored.contains {
                $0.time > previous.endTime + 0.001 && $0.time < next.startTime - 0.001
            }
            guard !hasExplicitGapPoint else { continue }

            let previousPosition = authored.last(where: { $0.time <= previous.endTime + 0.001 })?
                .position ?? group.defaultPosition
            let nextPosition = authored.first(where: { $0.time >= next.startTime - 0.001 })?
                .position ?? previousPosition
            result.append(
                SpatialGeneratedBoundaryKeyPoint(
                    id: "end-\(previous.id.uuidString)-\(next.id.uuidString)",
                    time: previous.endTime,
                    position: previousPosition,
                    attachment: .clipEnd(previous.id)
                )
            )
            result.append(
                SpatialGeneratedBoundaryKeyPoint(
                    id: "start-\(previous.id.uuidString)-\(next.id.uuidString)",
                    time: next.startTime,
                    position: nextPosition,
                    attachment: .clipStart(next.id)
                )
            )
        }
        return result
    }

    func trajectorySource(for source: SpatialEditorSourceGroup) -> SpatialEditorSourceGroup {
        var result = source
        result.keyPoints.append(contentsOf: automaticBoundaryKeyPoints(for: source.id).map { anchor in
            SpatialKeyPoint(
                time: anchor.time,
                position: anchor.position,
                createdByUser: false,
                interpolation: {
                    if case .clipEnd = anchor.attachment { return .hold }
                    return .smoothstep
                }()
            )
        })
        result.keyPoints.sort { $0.time < $1.time }
        return result
    }

    func setTimelineViewport(startTime: Double, span: Double) {
        timelineViewport = TimelineViewport(
            sceneDuration: duration,
            startTime: startTime,
            span: span
        )
    }

    func beginTimelineViewportInteraction() {
        isTimelineViewportInteracting = true
    }

    func endTimelineViewportInteraction() {
        isTimelineViewportInteracting = false
    }

    private func focusTimeline(on startTime: Double, preferredSpan: Double) {
        let span = min(max(preferredSpan, TimelineViewport.minimumSpan), duration)
        timelineViewport = TimelineViewport(
            sceneDuration: duration,
            startTime: startTime,
            span: span
        )
    }

    private func followPlayheadIfNeeded() {
        guard !isTimelineViewportInteracting else { return }
        if currentTime < timelineViewport.startTime
            || currentTime > timelineViewport.endTime {
            let leadingInset = timelineViewport.span * 0.10
            timelineViewport = TimelineViewport(
                sceneDuration: duration,
                startTime: currentTime - leadingInset,
                span: timelineViewport.span
            )
        }
    }

    private func compatibilitySources(for sourceGroupID: UUID) -> [SpatialEditorSource] {
        guard let group = source(id: sourceGroupID) else { return [] }
        return SpatialEditorDocument(
            sourceGroups: [group],
            audioClips: clips(for: sourceGroupID)
        ).legacySources()
    }

    private func clipNeighbors(
        for clip: SpatialEditorAudioClip
    ) -> (previous: SpatialEditorAudioClip?, next: SpatialEditorAudioClip?) {
        let ordered = clips(for: clip.sourceGroupID)
        guard let index = ordered.firstIndex(where: { $0.id == clip.id }) else {
            return (nil, nil)
        }
        return (
            index > 0 ? ordered[index - 1] : nil,
            index < ordered.count - 1 ? ordered[index + 1] : nil
        )
    }

    private func snappedTime(_ time: Double, candidates: [Double]) -> Double {
        candidates.first(where: { abs($0 - time) <= timeSnapTolerance }) ?? time
    }

    private func sortKeyPoints(sourceIndex: Int) {
        sourceGroups[sourceIndex].keyPoints.sort { $0.time < $1.time }
    }

    private func makeRoomForManualPoint(sourceIndex: Int, at time: Double) {
        let clips = sourceGroups[sourceIndex].motionClips ?? []
        guard clips.contains(where: { time >= $0.startTime && time <= $0.endTime }) else {
            return
        }

        let halfGap = 0.025
        var next: [SpatialMotionClip] = []
        for clip in clips {
            guard time >= clip.startTime && time <= clip.endTime else {
                next.append(clip)
                continue
            }
            if let leading = SpatialTrajectory.sliced(
                clip,
                from: clip.startTime,
                through: time - halfGap
            ) {
                next.append(leading)
            }
            if let trailing = SpatialTrajectory.sliced(
                clip,
                from: time + halfGap,
                through: clip.endTime
            ) {
                next.append(trailing)
            }
        }
        sourceGroups[sourceIndex].motionClips = next.isEmpty
            ? nil
            : next.sorted { $0.startTime < $1.startTime }
    }
}

private struct TrajectoryUndoState {
    let sourceID: UUID
    let keyPoints: [SpatialKeyPoint]
    let motionClips: [SpatialMotionClip]?
}
