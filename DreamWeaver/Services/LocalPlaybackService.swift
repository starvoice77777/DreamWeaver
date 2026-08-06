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
    private var automationEnvelopes: [UUID: Double] = [:]
    private var fadeMultipliers: [UUID: Float] = [:]
    private var currentSources: [UUID: SoundSource] = [:]
    private var configuredResources: [UUID: String] = [:]
    private var resourceByNode: [ObjectIdentifier: String] = [:]
    private var oneShotPlaybackTokens: [UUID: UUID] = [:]

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

    /// Fired when timeline automation mutates a source (position / enable).
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
        do {
            try configureSession()
        } catch {
            lastErrorMessage = error.localizedDescription
            throw ServiceError.invalidState("音频会话启动失败：\(error.localizedDescription)")
        }

        prepareSpatialGraph()

        currentSources = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, $0) })
        let resolvedTimeline = resolvedTimeline(timeline)
        activeTimeline = resolvedTimeline
        phraseById = Dictionary(
            uniqueKeysWithValues: (resolvedTimeline?.phrases ?? []).map { ($0.id, $0) }
        )
        let initiallyHiddenTrackIDs = prepareInitialTimelineVisibility(resolvedTimeline)
        let preparedSources = sources.map { currentSources[$0.id] ?? $0 }
        automationEnvelopes = Dictionary(
            uniqueKeysWithValues: preparedSources.map { ($0.id, $0.initialEnvelope) }
        )
        configuredResources = desiredResourceMap(for: preparedSources)
        let attachedTrackCount = attachAvailableTracks(preparedSources)

        configureTimelineScheduler(resolvedTimeline)
        initiallyHiddenTrackIDs.forEach(publishTimelineSource)

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
        for (id, node) in players
        where layers[id] != .voice && currentSources[id]?.isEnabled == true {
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

    func updateSource(id: UUID, position: SpatialPosition, enabled: Bool) {
        guard let node = players[id], var updated = currentSources[id] else { return }
        updated.position = position
        updated.isEnabled = enabled
        currentSources[id] = updated
        node.volume = renderedGain(for: id, source: updated)
        SpatialMixMapping.applySourceSpatialization(
            to: node,
            position: position,
            environment: environment
        )
    }

    func syncSources(_ sources: [SoundSource]) {
        prepareSpatialGraph()
        let previousEnvelopes = automationEnvelopes
        currentSources = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, $0) })
        automationEnvelopes = Dictionary(
            uniqueKeysWithValues: sources.map {
                ($0.id, previousEnvelopes[$0.id] ?? $0.initialEnvelope)
            }
        )

        let desiredResources = desiredResourceMap(for: sources)
        let previousResources = configuredResources
        let removedOrReplacedIds = previousResources.keys.filter {
            desiredResources[$0] != previousResources[$0]
        }
        let addedOrReplacedSources = sources.filter { source in
            guard source.resourceName != nil else { return false }
            return previousResources[source.id] != source.resourceName
        }
        var failures: [String] = []

        // AVAudioEngine supports changing player-node connections while the
        // mixer keeps rendering. Only the affected source is stopped.
        for id in removedOrReplacedIds {
            detach(id: id)
        }

        for source in addedOrReplacedSources {
            do {
                let attached = try attach(source: source)
                if !attached {
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

            // Start every newly-visible bed, not just newly-attached nodes. Create
            // preview keeps future clips attached and muted; when the playhead
            // enters their window their resource map is unchanged, so limiting
            // this to `newlyAttachedIds` left those clips permanently silent.
            for id in players.keys
            where layers[id] != .voice && currentSources[id]?.isEnabled == true {
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
        duration: TimeInterval,
        usesAcceleratedFade: Bool,
        onTick: @escaping (Double) -> Void,
        onFinished: @escaping () -> Void
    ) {
        cancelSleepTimer()
        guard duration > 0 else { return }
        onSleepTick = onTick
        onSleepFinished = onFinished
        sleepDuration = duration
        sleepStartedAt = Date()

        if usesAcceleratedFade {
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

    private func resolvedTimeline(
        _ timeline: APIContentDTO.SceneTimeline?
    ) -> APIContentDTO.SceneTimeline? {
        // When caller passes nil, use hair-care-compatible local fixture if a voice track is present.
        if let timeline {
            return timeline
        }
        if currentSources.values.contains(where: { $0.layer == .voice }) {
            return LocalTimelineFixture.timeline(for: DemoIDs.hairCareScene)
        }
        return nil
    }

    /// Timeline-controlled tracks start outside the scene and enter only when
    /// their first enable/play action fires. This keeps the mix disk aligned
    /// with the authored lifecycle even when catalog defaults are all enabled.
    private func prepareInitialTimelineVisibility(
        _ timeline: APIContentDTO.SceneTimeline?
    ) -> [UUID] {
        let activationTypes: Set<String> = ["enable", "play", "play_oneshot", "play_phrase"]
        let phraseTracks = Dictionary(
            uniqueKeysWithValues: (timeline?.phrases ?? []).compactMap { phrase in
                phrase.voice_binding.track_id.map { (phrase.id, $0) }
            }
        )
        let controlledIDs = Set((timeline?.cues ?? []).flatMap(\.actions).compactMap { action in
            guard activationTypes.contains(action.type) else { return nil }
            return action.track_id ?? action.phrase_id.flatMap { phraseTracks[$0] }
        })
        for id in controlledIDs {
            guard var source = currentSources[id] else { continue }
            source.isEnabled = false
            currentSources[id] = source
        }
        return Array(controlledIDs)
    }

    private func configureTimelineScheduler(_ timeline: APIContentDTO.SceneTimeline?) {
        timelineScheduler.configure(timeline: timeline, overrides: []) { [weak self] actions in
            self?.executeTimelineActions(actions)
        }
    }

    private func executeTimelineActions(_ actions: [APIContentDTO.CueAction]) {
        // Some authored cues enable a track before setting its envelope to zero.
        // Prime zero envelopes first to prevent a one-frame audible flash.
        let activatingTrackIDs = Set(actions.compactMap { action -> UUID? in
            ["enable", "play", "play_oneshot", "play_phrase"].contains(action.type)
                ? action.track_id
                : nil
        })
        var primedZeroEnvelopeTrackIDs: Set<UUID> = []
        for action in actions
        where action.type == "set_envelope"
            && (action.envelope ?? 1) <= 0
            && (action.fade_ms ?? 0) <= 50 {
            if let id = action.track_id, activatingTrackIDs.contains(id) {
                applyEnvelope(trackId: id, envelope: 0, fadeMs: 0)
                primedZeroEnvelopeTrackIDs.insert(id)
            }
        }
        for action in actions {
            switch action.type {
            case "play_phrase":
                playPhraseAction(action)
            case "play_oneshot":
                if let id = action.track_id {
                    setTimelineSourceEnabled(id, enabled: true)
                }
                if let id = action.track_id, let source = currentSources[id] {
                    playOneShot(source: source)
                }
            case "set_envelope":
                if let id = action.track_id, let envelope = action.envelope {
                    if envelope <= 0, primedZeroEnvelopeTrackIDs.contains(id) { continue }
                    applyEnvelope(trackId: id, envelope: envelope, fadeMs: action.fade_ms)
                }
            case "fade_out":
                if let id = action.track_id {
                    applyEnvelope(trackId: id, envelope: 0, fadeMs: action.fade_ms ?? 2000)
                }
            case "fade_in":
                if let id = action.track_id {
                    let target = action.envelope ?? currentSources[id]?.initialEnvelope ?? 1
                    applyEnvelope(trackId: id, envelope: target, fadeMs: action.fade_ms ?? 2000)
                }
            case "set_position":
                if let id = action.track_id,
                   let angle = action.angle,
                   let radius = action.radius,
                   var source = currentSources[id] {
                    source.position = SpatialPosition(angle: angle, radius: radius)
                    currentSources[id] = source
                    updateSource(id: id, position: source.position, enabled: source.isEnabled)
                    publishTimelineSource(id)
                }
            case "enable":
                if let id = action.track_id {
                    setTimelineSourceEnabled(id, enabled: true)
                }
            case "disable":
                if let id = action.track_id {
                    oneShotPlaybackTokens[id] = nil
                    setTimelineSourceEnabled(id, enabled: false)
                }
            case "play":
                if let id = action.track_id {
                    setTimelineSourceEnabled(id, enabled: true)
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
                    setTimelineSourceEnabled(id, enabled: false)
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

    private func setTimelineSourceEnabled(_ id: UUID, enabled: Bool) {
        guard var source = currentSources[id] else { return }
        source.isEnabled = enabled
        currentSources[id] = source
        if enabled {
            ensureTrackAttached(source)
        }
        updateSource(id: id, position: source.position, enabled: enabled)
        publishTimelineSource(id)
    }

    private func playPhraseAction(_ action: APIContentDTO.CueAction) {
        let trackId = action.track_id
            ?? action.phrase_id.flatMap { phraseById[$0]?.voice_binding.track_id }
        guard let trackId else { return }
        setTimelineSourceEnabled(trackId, enabled: true)
        guard let source = currentSources[trackId], source.layer == .voice else { return }

        var oneshot = source
        if let phraseId = action.phrase_id,
           let phrase = phraseById[phraseId],
           let key = phrase.voice_binding.resource_key {
            oneshot.resourceName = key
        }
        playOneShot(source: oneshot)
    }

    private func applyEnvelope(trackId: UUID, envelope: Double, fadeMs: Int?) {
        guard let node = players[trackId], let source = currentSources[trackId] else { return }
        let clamped = min(max(envelope, 0), 1)
        let duration = Double(fadeMs ?? 0) / 1000.0
        automationEnvelopes[trackId] = clamped
        let target = renderedGain(for: trackId, source: source)
        if duration <= 0.05 {
            node.volume = target
            return
        }
        fadeTasks.append(Task { @MainActor [weak self] in
            guard let self else { return }
            let steps = 20
            let start = Double(node.volume)
            let stepTime = duration / Double(steps)
            for step in 0...steps {
                let t = Double(step) / Double(steps)
                let value = start + (Double(target) - start) * t
                node.volume = Float(value)
                try? await Task.sleep(nanoseconds: UInt64(stepTime * 1_000_000_000))
                if Task.isCancelled { return }
            }
        })
    }

    /// Final player gain has exactly one steady-state loudness term: board radius.
    /// Legacy presets authored envelope baselines below 1 (for example 0.22).
    /// Normalize against that baseline so it represents “fully active”; values
    /// below the baseline still preserve authored fades and temporary ducking.
    private func renderedGain(for id: UUID, source: SoundSource) -> Float {
        guard source.isEnabled else { return 0 }
        let envelope = automationEnvelopes[id] ?? source.initialEnvelope
        let baseline = source.initialEnvelope
        let automationMultiplier: Double
        if envelope <= 0 {
            automationMultiplier = 0
        } else if baseline > 0 {
            automationMultiplier = min(max(envelope / baseline, 0), 1)
        } else {
            automationMultiplier = 1
        }
        let fade = Double(fadeMultipliers[id] ?? 1)
        return Float(
            SpatialMixMapping.gain(for: source.position.radius)
                * automationMultiplier
                * fade
        )
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
            node.volume = renderedGain(for: source.id, source: source)
        }

        players[source.id] = node
        layers[source.id] = source.layer
        automationEnvelopes[source.id] = automationEnvelopes[source.id] ?? source.initialEnvelope
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
            let sourceID = source.id
            let playbackToken = UUID()
            oneShotPlaybackTokens[sourceID] = playbackToken
            node.volume = renderedGain(for: sourceID, source: source)
            SpatialMixMapping.applySourceSpatialization(
                to: node,
                position: source.position,
                environment: environment
            )
            node.stop()
            node.scheduleFile(
                file,
                at: nil,
                completionCallbackType: .dataPlayedBack
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self,
                          self.oneShotPlaybackTokens[sourceID] == playbackToken else { return }
                    self.oneShotPlaybackTokens[sourceID] = nil
                    self.setTimelineSourceEnabled(sourceID, enabled: false)
                }
            }
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
                if let node = players[id], let source = currentSources[id] {
                    node.volume = renderedGain(for: id, source: source)
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
        automationEnvelopes[id] = nil
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
        oneShotPlaybackTokens = [:]
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
        // Older remote rows and saved compositions may still reference the
        // silent placeholder. Resolve them to the first mastered phrase so an
        // existing user's scene does not remain permanently mute after upgrade.
        let resolvedName = name == "voice_phrase_mom" ? "voice_phrase_01" : name
        let ns = resolvedName as NSString
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
}
