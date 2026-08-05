import Foundation
import AVFoundation
import Combine

/// Multi-track local playback with Apple `AVAudioEnvironmentNode` spatialization.
@MainActor
final class LocalPlaybackService: ObservableObject, PlaybackService {
    @Published private(set) var isPlaying = false
    @Published private(set) var progress: Double = 0.12
    @Published private(set) var lastErrorMessage: String?

    private let engine = AVAudioEngine()
    private let environment = AVAudioEnvironmentNode()
    private var playbackRequested = false
    private var players: [UUID: AVAudioPlayerNode] = [:]
    private var layers: [UUID: AudioLayerKind] = [:]
    private var baseVolumes: [UUID: Double] = [:]
    private var fadeMultipliers: [UUID: Float] = [:]
    private var currentSources: [UUID: SoundSource] = [:]
    private var configuredResources: [UUID: String] = [:]
    private var resourceByNode: [ObjectIdentifier: String] = [:]

    private var progressTimer: Timer?
    private var sleepTimer: Timer?
    private var sleepStartedAt: Date?
    private var sleepDuration: TimeInterval = 0
    private var fadeTasks: [Task<Void, Never>] = []
    private var previewPlayer: AVAudioPlayerNode?
    private let timelineScheduler = SceneTimelineScheduler()
    private var activeTimeline: APIContentDTO.SceneTimeline?
    private var phraseById: [UUID: APIContentDTO.Phrase] = [:]

    private var onSleepTick: ((Double) -> Void)?
    private var onSleepFinished: (() -> Void)?
    private let debugRunId = "run-2-preset-position-fix"

    /// Fired when timeline automation mutates a source (position / enable / volume).
    /// AppState uses this to keep the mix disk in sync without marking manual overrides.
    var onTimelineSourceChange: ((UUID, SoundSource) -> Void)?

    func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)
    }

    func load(scene: DreamScene, sources: [SoundSource]) throws {
        try load(scene: scene, sources: sources, timeline: nil)
    }

    func load(scene: DreamScene, sources: [SoundSource], timeline: APIContentDTO.SceneTimeline?) throws {
        // Rebuild the graph from a stopped state. Detaching nodes while the
        // engine is running can leave AVAudioEngine with an invalid graph.
        stopInternal(keepEngine: false)
        lastErrorMessage = nil
        activeTimeline = timeline
        phraseById = Dictionary(uniqueKeysWithValues: (timeline?.phrases ?? []).map { ($0.id, $0) })

        do {
            try configureSession()
        } catch {
            lastErrorMessage = error.localizedDescription
            throw ServiceError.invalidState("音频会话启动失败：\(error.localizedDescription)")
        }

        prepareSpatialGraph()

        currentSources = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, $0) })
        configuredResources = desiredResourceMap(for: sources)
        let attachedTrackCount = attachAvailableTracks(sources)

        configureTimelineScheduler(timeline)

        guard attachedTrackCount > 0 else {
            isPlaying = false
            lastErrorMessage = "当前场景暂无可播放的本地音频"
            return
        }
    }

    /// User edited a track — exit official automation for that track only.
    func markManualOverride(trackId: UUID) {
        timelineScheduler.markManualOverride(trackId: trackId)
    }

    func play() {
        playbackRequested = true
        guard !players.isEmpty else {
            isPlaying = false
            lastErrorMessage = "当前场景暂无可播放的本地音频"
            return
        }
        do {
            try startEngineIfNeeded()
        } catch {
            isPlaying = false
            lastErrorMessage = error.localizedDescription
            return
        }
        isPlaying = true
        for (id, node) in players where layers[id] != .voice {
            if !node.isPlaying { node.play() }
        }
        timelineScheduler.start()
        startProgress()
    }

    func pause() {
        playbackRequested = false
        for (_, node) in players {
            node.pause()
        }
        isPlaying = false
        progressTimer?.invalidate()
        progressTimer = nil
        timelineScheduler.pause()
    }

    func stop() {
        playbackRequested = false
        stopInternal(keepEngine: false)
        isPlaying = false
        progress = 0.08
    }

    func updateSource(id: UUID, volume: Double, position: SpatialPosition, enabled: Bool) {
        guard let node = players[id] else { return }
        let fade = fadeMultipliers[id] ?? 1
        let gain = Float(max(volume, 0)) * fade
        node.volume = enabled ? gain : 0
        SpatialMixMapping.applySourceSpatialization(
            to: node,
            position: position,
            environment: environment
        )
        baseVolumes[id] = volume
        if let existing = currentSources[id] {
            var updated = existing
            updated.volume = volume
            updated.position = position
            updated.isEnabled = enabled
            currentSources[id] = updated
        }
    }

    func syncSources(_ sources: [SoundSource]) {
        prepareSpatialGraph()
        currentSources = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, $0) })

        let desiredResources = desiredResourceMap(for: sources)
        let previousResources = configuredResources
        let removedOrReplacedIds = previousResources.keys.filter {
            desiredResources[$0] != previousResources[$0]
        }
        let addedOrReplacedSources = sources.filter { source in
            guard source.resourceName != nil else { return false }
            return previousResources[source.id] != source.resourceName
        }
        let engineWasRunning = engine.isRunning
        var newlyAttachedIds: [UUID] = []
        var failures: [String] = []

        // AVAudioEngine supports changing player-node connections while the
        // mixer keeps rendering. Only the affected source is stopped.
        for id in removedOrReplacedIds {
            detach(id: id)
        }

        for source in addedOrReplacedSources {
            do {
                if try attach(source: source) {
                    newlyAttachedIds.append(source.id)
                } else {
                    failures.append(source.name)
                }
            } catch {
                failures.append("\(source.name)：\(error.localizedDescription)")
            }
        }
        configuredResources = desiredResources

        for source in sources {
            updateSource(
                id: source.id,
                volume: source.volume,
                position: source.position,
                enabled: source.isEnabled
            )
        }

        if players.isEmpty {
            if engine.isRunning {
                engine.stop()
            }
            isPlaying = false
            return
        }

        guard playbackRequested else {
            isPlaying = false
            return
        }

        do {
            try startEngineIfNeeded()
            isPlaying = true

            let idsToStart = engineWasRunning ? newlyAttachedIds : Array(players.keys)
            for id in idsToStart where layers[id] != .voice {
                if let node = players[id], !node.isPlaying {
                    node.play()
                }
            }
        } catch {
            isPlaying = false
            lastErrorMessage = error.localizedDescription
        }

        if !failures.isEmpty {
            lastErrorMessage = "部分音轨未能加载：\(failures.joined(separator: "、"))"
        }
    }

    func preview(resourceName: String?) {
        stopPreview()
        guard let resourceName, let url = Self.url(forResource: resourceName) else {
            lastErrorMessage = ServiceError.audioResourceMissing(resourceName ?? "nil").errorDescription
            return
        }
        do {
            try configureSession()
            prepareSpatialGraph()
            let file = try AVAudioFile(forReading: url)
            let node = AVAudioPlayerNode()
            engine.attach(node)
            // Preview stays non-spatial so library audition is consistent.
            engine.connect(node, to: engine.mainMixerNode, format: file.processingFormat)
            node.scheduleFile(file, at: nil, completionHandler: nil)
            previewPlayer = node
            try startEngineIfNeeded()
            node.volume = 0.8
            node.play()
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                self.stopPreview()
            }
        } catch {
            stopPreview()
            lastErrorMessage = error.localizedDescription
        }
    }

    func stopPreview() {
        guard let previewPlayer else { return }
        self.previewPlayer = nil
        previewPlayer.stop()
        guard engine.attachedNodes.contains(previewPlayer) else { return }
        engine.disconnectNodeOutput(previewPlayer)
        engine.detach(previewPlayer)
    }

    func startSleepTimer(
        option: TimerOption,
        onTick: @escaping (Double) -> Void,
        onFinished: @escaping () -> Void
    ) {
        cancelSleepTimer()
        guard let seconds = option.countdownSeconds, seconds > 0 else { return }
        onSleepTick = onTick
        onSleepFinished = onFinished
        sleepDuration = seconds
        sleepStartedAt = Date()

        if option == .demoAccelerated {
            // Layered fade for film takes; wall-clock `tickSleep` is the hard stop.
            performLayeredFade(phases: DemoFadeSchedule.accelerated) { [weak self] in
                self?.finishSleepTimer()
            }
        }

        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tickSleep()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        sleepTimer = timer
    }

    func cancelSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepStartedAt = nil
        onSleepTick = nil
        onSleepFinished = nil
        for task in fadeTasks { task.cancel() }
        fadeTasks.removeAll()
        for id in fadeMultipliers.keys { fadeMultipliers[id] = 1 }
    }

    func performLayeredFade(phases: [FadePhase], onFinished: @escaping () -> Void) {
        for task in fadeTasks { task.cancel() }
        fadeTasks.removeAll()

        let maxEnd = phases.map { $0.delaySeconds + $0.durationSeconds }.max() ?? 0
        for phase in phases {
            let task = Task { @MainActor [weak self] in
                guard let self else { return }
                try? await Task.sleep(nanoseconds: UInt64(phase.delaySeconds * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await self.fadeLayer(phase.layer, duration: phase.durationSeconds)
            }
            fadeTasks.append(task)
        }
        let finishTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64((maxEnd + 0.3) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            onFinished()
        }
        fadeTasks.append(finishTask)
    }

    // MARK: - Private graph

    /// Attach / reconnect the environment mixer used for HRTF spatialization.
    private func prepareSpatialGraph() {
        _ = engine.mainMixerNode
        _ = engine.outputNode

        if !engine.attachedNodes.contains(environment) {
            engine.attach(environment)
        }
        SpatialMixMapping.configureEnvironment(environment)
        engine.connect(environment, to: engine.mainMixerNode, format: nil)
    }

    private func startEngineIfNeeded() throws {
        guard !players.isEmpty || previewPlayer != nil else {
            throw ServiceError.invalidState("没有可连接到音频输出的播放节点")
        }
        guard !engine.isRunning else { return }

        prepareSpatialGraph()
        engine.prepare()
        do {
            try engine.start()
        } catch {
            throw ServiceError.invalidState(error.localizedDescription)
        }
    }

    private func attachAvailableTracks(_ sources: [SoundSource]) -> Int {
        var attachedCount = 0
        var failures: [String] = []

        // Attach disabled tracks too (muted). Timeline cues enable / fade them in.
        for source in sources where source.resourceName != nil {
            do {
                if try attach(source: source) {
                    attachedCount += 1
                } else {
                    failures.append(source.name)
                }
            } catch {
                failures.append("\(source.name)：\(error.localizedDescription)")
            }
        }

        if !failures.isEmpty {
            lastErrorMessage = "部分音轨未能加载：\(failures.joined(separator: "、"))"
        }
        return attachedCount
    }

    private func desiredResourceMap(for sources: [SoundSource]) -> [UUID: String] {
        Dictionary(uniqueKeysWithValues: sources.compactMap { source in
            guard let resourceName = source.resourceName else { return nil }
            return (source.id, resourceName)
        })
    }

    private func configureTimelineScheduler(_ timeline: APIContentDTO.SceneTimeline?) {
        // When caller passes nil, use hair-care-compatible local fixture if a voice track is present.
        let resolved: APIContentDTO.SceneTimeline?
        if let timeline {
            resolved = timeline
        } else if currentSources.values.contains(where: { $0.layer == .voice }) {
            resolved = LocalTimelineFixture.timeline(for: DemoIDs.hairCareScene)
            phraseById = Dictionary(uniqueKeysWithValues: (resolved?.phrases ?? []).map { ($0.id, $0) })
        } else {
            resolved = nil
        }
        activeTimeline = resolved
        // #region agent log
        debugLog(
            hypothesisId: "H5",
            location: "LocalPlaybackService.configureTimelineScheduler",
            message: "timeline scheduler configured",
            data: [
                "inputTimelineVersion": String(timeline?.version ?? -1),
                "resolvedTimelineVersion": String(resolved?.version ?? -1),
                "resolvedCueCount": String(resolved?.cues.count ?? 0),
                "sourceCount": String(currentSources.count),
                "voiceTrackCount": String(currentSources.values.filter { $0.layer == .voice }.count)
            ]
        )
        // #endregion

        timelineScheduler.configure(timeline: resolved, overrides: []) { [weak self] actions in
            self?.executeTimelineActions(actions)
        }
    }

    private func executeTimelineActions(_ actions: [APIContentDTO.CueAction]) {
        // #region agent log
        debugLog(
            hypothesisId: "H6",
            location: "LocalPlaybackService.executeTimelineActions",
            message: "timeline actions fired",
            data: [
                "actionCount": String(actions.count),
                "types": actions.map(\.type).joined(separator: ","),
                "trackIds": actions.compactMap { $0.track_id?.uuidString }.joined(separator: ",")
            ]
        )
        // #endregion
        for action in actions {
            switch action.type {
            case "play_phrase":
                playPhraseAction(action)
            case "play_oneshot":
                if let id = action.track_id, let source = currentSources[id] {
                    playOneShot(source: source)
                    publishTimelineSource(id)
                }
            case "set_volume":
                if let id = action.track_id, let volume = action.volume {
                    applyVolume(trackId: id, volume: volume, fadeMs: action.fade_ms, publish: true)
                }
            case "fade_out":
                if let id = action.track_id {
                    applyVolume(trackId: id, volume: 0, fadeMs: action.fade_ms ?? 2000, publish: true)
                }
            case "fade_in":
                if let id = action.track_id {
                    let target = currentSources[id]?.volume ?? baseVolumes[id] ?? 0.7
                    applyVolume(trackId: id, volume: target, fadeMs: action.fade_ms ?? 2000, publish: true)
                }
            case "set_position":
                if let id = action.track_id,
                   let angle = action.angle,
                   let radius = action.radius,
                   var source = currentSources[id] {
                    source.position = SpatialPosition(angle: angle, radius: radius)
                    currentSources[id] = source
                    updateSource(id: id, volume: source.volume, position: source.position, enabled: source.isEnabled)
                    publishTimelineSource(id)
                }
            case "enable":
                if let id = action.track_id, var source = currentSources[id] {
                    source.isEnabled = true
                    currentSources[id] = source
                    ensureTrackAttached(source)
                    updateSource(id: id, volume: source.volume, position: source.position, enabled: true)
                    if playbackRequested, let node = players[id], !node.isPlaying, layers[id] != .voice {
                        node.play()
                    }
                    publishTimelineSource(id)
                }
            case "disable":
                if let id = action.track_id, var source = currentSources[id] {
                    source.isEnabled = false
                    currentSources[id] = source
                    updateSource(id: id, volume: source.volume, position: source.position, enabled: false)
                    publishTimelineSource(id)
                }
            case "play":
                if let id = action.track_id {
                    if players[id] == nil, let source = currentSources[id] {
                        ensureTrackAttached(source)
                    }
                    if let node = players[id], !node.isPlaying {
                        node.play()
                    }
                }
            case "pause":
                if let id = action.track_id {
                    players[id]?.pause()
                }
            default:
                break
            }
        }
    }

    private func publishTimelineSource(_ id: UUID) {
        guard let source = currentSources[id] else { return }
        onTimelineSourceChange?(id, source)
    }

    private func playPhraseAction(_ action: APIContentDTO.CueAction) {
        let trackId = action.track_id
            ?? action.phrase_id.flatMap { phraseById[$0]?.voice_binding.track_id }
        guard let trackId,
              let source = currentSources[trackId],
              source.layer == .voice,
              source.isEnabled else { return }

        var oneshot = source
        if let phraseId = action.phrase_id,
           let phrase = phraseById[phraseId],
           let key = phrase.voice_binding.resource_key {
            oneshot.resourceName = key
        }
        playOneShot(source: oneshot)
    }

    private func applyVolume(trackId: UUID, volume: Double, fadeMs: Int?, publish: Bool = false) {
        guard players[trackId] != nil else { return }
        let clamped = min(max(volume, 0), 1)
        let duration = Double(fadeMs ?? 0) / 1000.0
        // Publish target level immediately so the mix disk tracks automation intent.
        if var source = currentSources[trackId] {
            source.volume = clamped
            currentSources[trackId] = source
            if publish { publishTimelineSource(trackId) }
        }
        if duration <= 0.05 {
            baseVolumes[trackId] = clamped
            let fade = fadeMultipliers[trackId] ?? 1
            players[trackId]?.volume = Float(clamped) * fade
            return
        }
        fadeTasks.append(Task { @MainActor [weak self] in
            guard let self else { return }
            let steps = 20
            let start = Double(self.players[trackId]?.volume ?? 0)
            let stepTime = duration / Double(steps)
            for step in 0...steps {
                let t = Double(step) / Double(steps)
                let value = start + (clamped - start) * t
                self.players[trackId]?.volume = Float(value)
                try? await Task.sleep(nanoseconds: UInt64(stepTime * 1_000_000_000))
                if Task.isCancelled { return }
            }
            self.baseVolumes[trackId] = clamped
        })
    }

    @discardableResult
    private func attach(source: SoundSource) throws -> Bool {
        guard let resourceName = source.resourceName else { return false }
        guard let url = Self.url(forResource: resourceName) else {
            let message = ServiceError.audioResourceMissing(resourceName).errorDescription ?? resourceName
            lastErrorMessage = message
            return false
        }

        prepareSpatialGraph()

        let file = try AVAudioFile(forReading: url)
        // Environment spatialization only applies to mono connections.
        guard let monoFormat = AVAudioFormat(
            standardFormatWithSampleRate: file.processingFormat.sampleRate,
            channels: 1
        ) else {
            return false
        }

        let node = AVAudioPlayerNode()
        engine.attach(node)
        engine.connect(node, to: environment, format: monoFormat)
        resourceByNode[ObjectIdentifier(node)] = resourceName

        SpatialMixMapping.applySourceSpatialization(
            to: node,
            position: source.position,
            environment: environment
        )

        if source.layer == .voice || source.layer == .trigger {
            // Oneshot layers stay silent until a timeline cue fires play_phrase / play_oneshot.
            node.volume = 0
        } else {
            scheduleLoop(node: node, file: file)
            // Keep disabled beds attached but silent until timeline / user enables them.
            node.volume = source.isEnabled ? Float(source.volume) : 0
        }

        players[source.id] = node
        layers[source.id] = source.layer
        baseVolumes[source.id] = source.volume
        fadeMultipliers[source.id] = 1
        return true
    }

    /// Lazily attach a timeline track that was missing from the initial graph.
    private func ensureTrackAttached(_ source: SoundSource) {
        guard players[source.id] == nil, source.resourceName != nil else { return }
        do {
            _ = try attach(source: source)
            configuredResources[source.id] = source.resourceName
        } catch {
            lastErrorMessage = "\(source.name)：\(error.localizedDescription)"
        }
    }

    private func scheduleLoop(node: AVAudioPlayerNode, file: AVAudioFile) {
        scheduleFileLoop(node: node, file: file)
    }

    private func scheduleFileLoop(node: AVAudioPlayerNode, file: AVAudioFile) {
        node.scheduleFile(file, at: nil, completionHandler: { [weak self, weak node] in
            Task { @MainActor in
                guard let self, let node, self.isPlaying, self.players.contains(where: { $0.value === node }) else { return }
                // Re-open file for next loop to avoid consuming the same AVAudioFile offset.
                if let name = self.resourceName(for: node),
                   let url = Self.url(forResource: name),
                   let next = try? AVAudioFile(forReading: url) {
                    self.scheduleFileLoop(node: node, file: next)
                    if !node.isPlaying { node.play() }
                }
            }
        })
    }

    private func resourceName(for node: AVAudioPlayerNode) -> String? {
        resourceByNode[ObjectIdentifier(node)]
    }

    private func playOneShot(source: SoundSource) {
        guard let resourceName = source.resourceName,
              let url = Self.url(forResource: resourceName),
              let node = players[source.id] else { return }
        do {
            let file = try AVAudioFile(forReading: url)
            let fade = fadeMultipliers[source.id] ?? 1
            node.volume = Float(source.volume) * fade
            SpatialMixMapping.applySourceSpatialization(
                to: node,
                position: source.position,
                environment: environment
            )
            node.stop()
            node.scheduleFile(file, at: nil, completionHandler: nil)
            node.play()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func fadeLayer(_ layer: AudioLayerKind, duration: Double) async {
        let ids = layers.filter { $0.value == layer }.map(\.key)
        let steps = 20
        let stepTime = duration / Double(steps)
        for step in 0...steps {
            let t = Float(1.0 - Double(step) / Double(steps))
            for id in ids {
                fadeMultipliers[id] = t
                if let node = players[id], let base = baseVolumes[id] {
                    node.volume = Float(base) * t
                }
            }
            try? await Task.sleep(nanoseconds: UInt64(stepTime * 1_000_000_000))
        }
        for id in ids {
            players[id]?.volume = 0
            fadeMultipliers[id] = 0
        }
    }

    private func detach(id: UUID) {
        guard let node = players[id] else { return }
        node.stop()
        resourceByNode.removeValue(forKey: ObjectIdentifier(node))
        if engine.attachedNodes.contains(node) {
            engine.disconnectNodeOutput(node)
            engine.detach(node)
        }
        players[id] = nil
        layers[id] = nil
        baseVolumes[id] = nil
        fadeMultipliers[id] = nil
    }

    private func stopInternal(keepEngine: Bool) {
        playbackRequested = false
        if engine.isRunning {
            engine.stop()
        }
        timelineScheduler.stop()
        activeTimeline = nil
        phraseById = [:]
        progressTimer?.invalidate()
        progressTimer = nil
        cancelSleepTimer()
        stopPreview()
        for id in Array(players.keys) {
            detach(id: id)
        }
        currentSources = [:]
        configuredResources = [:]
        if engine.attachedNodes.contains(environment) {
            engine.disconnectNodeOutput(environment)
            engine.detach(environment)
        }
        if !keepEngine {
            engine.reset()
        }
    }

    private func startProgress() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isPlaying else { return }
                self.progress = min(self.progress + 0.0035, 0.97)
            }
        }
    }

    private func tickSleep() {
        guard let started = sleepStartedAt, sleepDuration > 0 else { return }
        let elapsed = Date().timeIntervalSince(started)
        let fraction = min(max(elapsed / sleepDuration, 0), 1)
        onSleepTick?(fraction)
        if fraction >= 1 {
            finishSleepTimer()
        }
    }

    /// Single exit for countdown end (10/30/60 and demo accelerated). Idempotent.
    private func finishSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepStartedAt = nil
        for task in fadeTasks { task.cancel() }
        fadeTasks.removeAll()

        let tick = onSleepTick
        let finish = onSleepFinished
        onSleepTick = nil
        onSleepFinished = nil

        pause()
        tick?(1)
        finish?()
    }

    static func url(forResource name: String) -> URL? {
        let ns = name as NSString
        let base = ns.deletingPathExtension
        let ext = ns.pathExtension
        let candidates: [(String, String?)]
        if ext.isEmpty {
            candidates = [
                (base, "wav"), (base, "mp3"), (base, "m4a"), (base, "caf"), (base, "aiff"), (base, nil)
            ]
        } else {
            candidates = [(base, ext)]
        }
        for (b, e) in candidates {
            // Xcode may either flatten synchronized resources or preserve the
            // Resources/Audio directory hierarchy in the app bundle.
            for subdirectory in ["Audio", "Resources/Audio", nil] as [String?] {
                if let url = Bundle.main.url(
                    forResource: b,
                    withExtension: e,
                    subdirectory: subdirectory
                ) {
                    return url
                }
            }
        }
        return nil
    }

    private static var didAnnounceDebugLogPath = false

    private func debugLog(
        hypothesisId: String,
        location: String,
        message: String,
        data: [String: String]
    ) {
        struct Payload: Encodable {
            let sessionId: String
            let runId: String
            let hypothesisId: String
            let location: String
            let message: String
            let data: [String: String]
            let timestamp: Int64
        }
        let payload = Payload(
            sessionId: "f7559e",
            runId: debugRunId,
            hypothesisId: hypothesisId,
            location: location,
            message: message,
            data: data,
            timestamp: Int64(Date().timeIntervalSince1970 * 1000)
        )
        guard let encoded = try? JSONEncoder().encode(payload),
              var line = String(data: encoded, encoding: .utf8) else { return }
        line.append("\n")
        let bytes = Data(line.utf8)
        print("[DWDebug] \(line.trimmingCharacters(in: .newlines))")
        var wrotePaths: [String] = []
        for url in Self.debugLogURLs() {
            do {
                if FileManager.default.fileExists(atPath: url.path) {
                    let handle = try FileHandle(forWritingTo: url)
                    defer { try? handle.close() }
                    try handle.seekToEnd()
                    try handle.write(contentsOf: bytes)
                } else {
                    try bytes.write(to: url, options: .atomic)
                }
                wrotePaths.append(url.path)
            } catch {
                continue
            }
        }
        if !Self.didAnnounceDebugLogPath {
            Self.didAnnounceDebugLogPath = true
            print("[DWDebug] log paths: \(wrotePaths.joined(separator: " | "))")
        }
    }

    private static func debugLogURLs() -> [URL] {
        var urls: [URL] = []
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            urls.append(docs.appendingPathComponent("debug-f7559e.log"))
        }
        let fileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = fileURL
            .deletingLastPathComponent() // Services
            .deletingLastPathComponent() // DreamWeaver
            .deletingLastPathComponent() // repo root
        urls.append(repoRoot.appendingPathComponent("debug-f7559e.log"))
        urls.append(URL(fileURLWithPath: "/tmp/debug-f7559e.log"))
        return urls
    }
}
