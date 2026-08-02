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
    private var voicePhraseTimer: Timer?
    private var voicePhraseTask: Task<Void, Never>?

    private var onSleepTick: ((Double) -> Void)?
    private var onSleepFinished: (() -> Void)?

    func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)
    }

    func load(scene: DreamScene, sources: [SoundSource]) throws {
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
        configuredResources = desiredResourceMap(for: sources)
        let attachedTrackCount = attachAvailableTracks(sources)

        guard attachedTrackCount > 0 else {
            isPlaying = false
            lastErrorMessage = "当前场景暂无可播放的本地音频"
            return
        }
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
        scheduleVoicePhrasesIfNeeded()
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
        voicePhraseTimer?.invalidate()
        voicePhraseTimer = nil
        voicePhraseTask?.cancel()
        voicePhraseTask = nil
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
            guard source.isEnabled, let resourceName = source.resourceName else { return false }
            return previousResources[source.id] != resourceName
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
            refreshVoicePhraseScheduling()
            return
        }

        guard playbackRequested else {
            isPlaying = false
            refreshVoicePhraseScheduling()
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
            refreshVoicePhraseScheduling()
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
            performLayeredFade(phases: DemoFadeSchedule.accelerated) { [weak self] in
                self?.pause()
                onFinished()
            }
        }

        sleepTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tickSleep()
            }
        }
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

        for source in sources where source.isEnabled {
            do {
                if try attach(source: source) {
                    attachedCount += 1
                } else if source.resourceName != nil {
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
            guard source.isEnabled, let resourceName = source.resourceName else { return nil }
            return (source.id, resourceName)
        })
    }

    private func refreshVoicePhraseScheduling() {
        let hasPlayableVoice = currentSources.values.contains {
            $0.layer == .voice
                && $0.isEnabled
                && $0.resourceName != nil
                && players[$0.id] != nil
        }

        if playbackRequested, hasPlayableVoice {
            if voicePhraseTimer == nil, voicePhraseTask == nil {
                scheduleVoicePhrasesIfNeeded()
            }
            return
        }

        voicePhraseTimer?.invalidate()
        voicePhraseTimer = nil
        voicePhraseTask?.cancel()
        voicePhraseTask = nil
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

        if source.layer == .voice {
            // Voice phrases are scheduled on a timer; attach silent-ready node.
            node.volume = 0
        } else {
            scheduleLoop(node: node, file: file)
            node.volume = Float(source.volume)
        }

        players[source.id] = node
        layers[source.id] = source.layer
        baseVolumes[source.id] = source.volume
        fadeMultipliers[source.id] = 1
        return true
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

    private func scheduleVoicePhrasesIfNeeded() {
        voicePhraseTimer?.invalidate()
        voicePhraseTimer = nil
        voicePhraseTask?.cancel()
        voicePhraseTask = nil

        let hasPlayableVoice = currentSources.values.contains {
            $0.layer == .voice
                && $0.isEnabled
                && $0.resourceName != nil
                && players[$0.id] != nil
        }
        guard hasPlayableVoice else { return }

        voicePhraseTimer = Timer.scheduledTimer(withTimeInterval: 28, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isPlaying else { return }
                self.playCurrentVoicePhrases()
            }
        }
        // First phrase after a short delay so environment settles.
        voicePhraseTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard let self, !Task.isCancelled, self.isPlaying else { return }
            self.playCurrentVoicePhrases()
        }
    }

    private func playCurrentVoicePhrases() {
        for source in currentSources.values
            where source.layer == .voice && source.isEnabled && source.resourceName != nil {
            playOneShot(source: source)
        }
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
        voicePhraseTimer?.invalidate()
        voicePhraseTimer = nil
        voicePhraseTask?.cancel()
        voicePhraseTask = nil
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
            sleepTimer?.invalidate()
            sleepTimer = nil
            if sleepDuration > 50 {
                // Non-accelerated timers: simple pause at end.
                pause()
                onSleepFinished?()
            }
        }
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
}
