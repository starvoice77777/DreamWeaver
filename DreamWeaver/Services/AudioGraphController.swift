import Foundation
@preconcurrency import AVFoundation

/// AVFoundation executor for a compiled plan. Each source group owns exactly
/// one spatial mixer; any number of clip players feed it underneath the UI.
@MainActor
final class AudioGraphController {
    var onError: ((String) -> Void)?

    private final class GroupGraph {
        let group: SceneSourceGroup
        let mixer = AVAudioMixerNode()
        var isEnabled = true
        var nextInputBus: AVAudioNodeBus = 0

        init(group: SceneSourceGroup) {
            self.group = group
        }
    }

    private final class ClipGraph {
        let clip: SceneAudioClip
        let loopBuffer: AVAudioPCMBuffer?
        let sourceDuration: Double
        let resourceURL: URL
        let players: [AVAudioPlayerNode]
        let masteringUnits: [AVAudioUnitEQ]
        var primaryIndex = 0
        var envelope: Float = 1
        var instanceWeights: [Float]

        init(
            clip: SceneAudioClip,
            loopBuffer: AVAudioPCMBuffer?,
            sourceDuration: Double,
            resourceURL: URL,
            players: [AVAudioPlayerNode],
            masteringUnits: [AVAudioUnitEQ]
        ) {
            self.clip = clip
            self.loopBuffer = loopBuffer
            self.sourceDuration = sourceDuration
            self.resourceURL = resourceURL
            self.players = players
            self.masteringUnits = masteringUnits
            self.instanceWeights = players.indices.map { $0 == 0 ? 1 : 0 }
        }
    }

    private let engine = AVAudioEngine()
    private let environment = AVAudioEnvironmentNode()
    private var plan: SceneRenderPlan?
    private var groups: [UUID: GroupGraph] = [:]
    private var clips: [UUID: ClipGraph] = [:]
    private var activeClipIDs: Set<UUID> = []
    private var crossfadeTasks: [UUID: Task<Void, Never>] = [:]
    private var latestState: RendererState = .empty
    private var nextEnvironmentInputBus: AVAudioNodeBus = 0
    private var layerFadeMultipliers: [AudioLayerKind: Float] = [:]
    private(set) var isPlaying = false

    var hasPlayableClips: Bool { !clips.isEmpty }

    func load(plan: SceneRenderPlan) throws {
        stop()
        tearDownGraph()
        self.plan = plan
        prepareEnvironment()

        for group in plan.sourceGroups {
            let graph = GroupGraph(group: group)
            engine.attach(graph.mixer)
            guard let mono = AVAudioFormat(
                standardFormatWithSampleRate: 48_000,
                channels: 1
            ) else { continue }
            engine.connect(
                graph.mixer,
                to: environment,
                fromBus: 0,
                toBus: nextEnvironmentInputBus,
                format: mono
            )
            nextEnvironmentInputBus += 1
            SpatialMixMapping.applySourceSpatialization(
                to: graph.mixer,
                position: group.defaultPosition,
                environment: environment
            )
            graph.mixer.outputVolume = 0
            groups[group.id] = graph
        }

        var failures: [String] = []
        var buffersByResource: [String: AVAudioPCMBuffer] = [:]
        for clip in plan.clips {
            guard let resource = clip.resourceKey,
                  let group = groups[clip.sourceGroupID],
                  let url = LocalPlaybackService.url(forResource: resource) else {
                failures.append(clip.resourceKey ?? clip.id.uuidString)
                continue
            }
            do {
                let file = try AVAudioFile(forReading: url)
                let sourceDuration = Double(file.length) / file.processingFormat.sampleRate
                let loopBuffer: AVAudioPCMBuffer?
                if clip.playbackMode == .oneshot {
                    loopBuffer = nil
                } else if let cached = buffersByResource[resource] {
                    loopBuffer = cached
                } else {
                    guard let loaded = AVAudioPCMBuffer(
                        pcmFormat: file.processingFormat,
                        frameCapacity: AVAudioFrameCount(file.length)
                    ) else {
                        failures.append(resource)
                        continue
                    }
                    try file.read(into: loaded)
                    buffersByResource[resource] = loaded
                    loopBuffer = loaded
                }
                let instanceCount = clip.crossfadeMilliseconds > 0 ? 2 : 1
                var players: [AVAudioPlayerNode] = []
                var masteringUnits: [AVAudioUnitEQ] = []
                for _ in 0..<instanceCount {
                    let player = AVAudioPlayerNode()
                    let mastering = AVAudioUnitEQ(numberOfBands: 1)
                    mastering.bands.first?.bypass = true
                    mastering.globalGain = AudioMasteringProfile.compensationDB(
                        for: clip.masteringProfileKey ?? resource
                    )
                    engine.attach(player)
                    engine.attach(mastering)
                    engine.connect(player, to: mastering, format: file.processingFormat)
                    engine.connect(
                        mastering,
                        to: group.mixer,
                        fromBus: 0,
                        toBus: group.nextInputBus,
                        format: file.processingFormat
                    )
                    group.nextInputBus += 1
                    players.append(player)
                    masteringUnits.append(mastering)
                }
                clips[clip.id] = ClipGraph(
                    clip: clip,
                    loopBuffer: loopBuffer,
                    sourceDuration: sourceDuration,
                    resourceURL: url,
                    players: players,
                    masteringUnits: masteringUnits
                )
            } catch {
                failures.append("\(resource): \(error.localizedDescription)")
            }
        }
        if !failures.isEmpty {
            onError?("部分音频未能加载：\(failures.joined(separator: "、"))")
        }
    }

    func play(state: RendererState) throws {
        latestState = state
        guard hasPlayableClips else {
            throw ServiceError.invalidState("当前场景暂无可播放的本地音频")
        }
        if !engine.isRunning {
            prepareEnvironment()
            engine.prepare()
            try engine.start()
        }
        isPlaying = true
        resynchronize(at: state.time, desiredClipIDs: state.activeClipIDs)
        apply(state)
    }

    func pause() {
        isPlaying = false
        cancelCrossfades()
        for graph in clips.values {
            graph.players.forEach { $0.pause() }
        }
    }

    func stop() {
        isPlaying = false
        cancelCrossfades()
        for graph in clips.values {
            graph.players.forEach { $0.stop() }
        }
        activeClipIDs = []
        if engine.isRunning { engine.stop() }
    }

    func apply(_ state: RendererState, reconcileClips: Bool = true) {
        latestState = state
        for sourceState in state.sourceGroups {
            guard let group = groups[sourceState.id] else { continue }
            SpatialMixMapping.applySourceSpatialization(
                to: group.mixer,
                position: sourceState.position,
                environment: environment
            )
            let layerFade = Double(layerFadeMultipliers[group.group.layer] ?? 1)
            let gain = group.isEnabled
                ? sourceState.radialGain * sourceState.automationGain * layerFade
                : 0
            group.mixer.outputVolume = Float(min(max(gain, 0), 1))
        }

        for id in state.activeClipIDs {
            guard let graph = clips[id] else { continue }
            graph.envelope = clipEnvelope(for: graph.clip, at: state.time)
            for index in graph.players.indices {
                graph.players[index].volume = graph.instanceWeights[index] * graph.envelope
            }
        }

        guard isPlaying, reconcileClips else { return }
        let stopped = activeClipIDs.subtracting(state.activeClipIDs)
        let started = state.activeClipIDs.subtracting(activeClipIDs)
        stopped.forEach(stopClip)
        started.forEach { startClip($0, at: state.time) }
        activeClipIDs = state.activeClipIDs.intersection(Set(clips.keys))
    }

    func setGroupEnabled(_ enabled: Bool, id: UUID) {
        groups[id]?.isEnabled = enabled
        apply(latestState)
    }

    func setLayerFade(_ multiplier: Float, layer: AudioLayerKind) {
        layerFadeMultipliers[layer] = min(max(multiplier, 0), 1)
        apply(latestState)
    }

    func resetLayerFades() {
        layerFadeMultipliers = [:]
        apply(latestState)
    }

    func resynchronize(at time: Double, desiredClipIDs: Set<UUID>) {
        activeClipIDs.forEach(stopClip)
        activeClipIDs = []
        guard isPlaying else { return }
        desiredClipIDs.forEach { startClip($0, at: time) }
        activeClipIDs = desiredClipIDs.intersection(Set(clips.keys))
    }

    private func startClip(_ id: UUID, at sceneTime: Double) {
        guard let graph = clips[id], !graph.players.isEmpty else { return }
        stopClip(id)
        graph.envelope = clipEnvelope(for: graph.clip, at: sceneTime)
        graph.instanceWeights = graph.players.indices.map { $0 == 0 ? 1 : 0 }
        let offset = max(sceneTime - graph.clip.startSeconds + graph.clip.sourceOffsetSeconds, 0)
        switch graph.clip.playbackMode {
        case .oneshot:
            scheduleOneShot(graph, offset: offset)
        case .loop, .boundedLoop:
            scheduleLoop(graph, offset: offset)
        }
    }

    private func scheduleOneShot(_ graph: ClipGraph, offset: Double) {
        let player = graph.players[0]
        guard let file = try? AVAudioFile(forReading: graph.resourceURL) else { return }
        let startFrame = min(
            AVAudioFramePosition(offset * file.processingFormat.sampleRate),
            max(file.length - 1, 0)
        )
        let frameCount = AVAudioFrameCount(max(file.length - startFrame, 0))
        guard frameCount > 0 else { return }
        player.volume = graph.envelope
        player.scheduleSegment(
            file,
            startingFrame: startFrame,
            frameCount: frameCount,
            at: nil,
            completionHandler: nil
        )
        player.play()
    }

    private func scheduleLoop(_ graph: ClipGraph, offset: Double) {
        guard graph.loopBuffer != nil else { return }
        let primary = graph.players[0]
        primary.volume = graph.envelope
        let sourceDuration = graph.sourceDuration
        let phase = sourceDuration > 0 ? offset.truncatingRemainder(dividingBy: sourceDuration) : 0
        scheduleRepeating(graph, player: primary, phase: phase)
        guard graph.players.count == 2 else { return }
        startCrossfadeCycle(for: graph, initialPhase: phase)
    }

    private func scheduleRepeating(
        _ graph: ClipGraph,
        player: AVAudioPlayerNode,
        phase: Double
    ) {
        guard let buffer = graph.loopBuffer else { return }
        if phase > 0,
           let file = try? AVAudioFile(forReading: graph.resourceURL) {
            let startFrame = min(
                AVAudioFramePosition(phase * file.processingFormat.sampleRate),
                max(file.length - 1, 0)
            )
            player.scheduleSegment(
                file,
                startingFrame: startFrame,
                frameCount: AVAudioFrameCount(max(file.length - startFrame, 0)),
                at: nil,
                completionHandler: nil
            )
        }
        player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        player.play()
    }

    private func startCrossfadeCycle(for graph: ClipGraph, initialPhase: Double) {
        let clipID = graph.clip.id
        crossfadeTasks[clipID]?.cancel()
        let sourceDuration = graph.sourceDuration
        let overlap = LoopCrossfadeController.validatedDuration(
            milliseconds: graph.clip.crossfadeMilliseconds,
            sourceDurationSeconds: sourceDuration
        )
        guard overlap > 0, sourceDuration > overlap else { return }
        let overlapStart = sourceDuration - overlap
        let resumeProgress = initialPhase > overlapStart
            ? min(max((initialPhase - overlapStart) / overlap, 0), 1)
            : 0
        if resumeProgress > 0 {
            let weights = LoopCrossfadeController.gains(at: resumeProgress)
            graph.instanceWeights[graph.primaryIndex] = weights.outgoing
            graph.instanceWeights[graph.primaryIndex == 0 ? 1 : 0] = weights.incoming
            graph.players[graph.primaryIndex].volume = weights.outgoing * graph.envelope
        }
        crossfadeTasks[clipID] = Task { @MainActor [weak self, clipID] in
            guard let self, let graph = self.clips[clipID] else { return }
            var delay = max(overlapStart - initialPhase, 0)
            var transitionStart = resumeProgress
            while self.isPlaying,
                  self.activeClipIDs.contains(clipID) || self.latestState.activeClipIDs.contains(clipID),
                  !Task.isCancelled {
                do {
                    try await Task.sleep(
                        nanoseconds: UInt64(delay * 1_000_000_000)
                    )
                } catch { return }
                guard self.isPlaying, !Task.isCancelled else { return }
                let outgoing = graph.primaryIndex
                let incoming = outgoing == 0 ? 1 : 0
                let incomingPlayer = graph.players[incoming]
                incomingPlayer.stop()
                let startingGains = LoopCrossfadeController.gains(at: transitionStart)
                graph.instanceWeights[outgoing] = startingGains.outgoing
                graph.instanceWeights[incoming] = startingGains.incoming
                incomingPlayer.volume = startingGains.incoming * graph.envelope
                self.scheduleRepeating(
                    graph,
                    player: incomingPlayer,
                    phase: transitionStart * overlap
                )
                let remainingOverlap = overlap * (1 - transitionStart)
                let steps = max(Int(remainingOverlap * 60), 2)
                for step in 0...steps {
                    guard self.isPlaying, !Task.isCancelled else { return }
                    let progress = transitionStart
                        + (1 - transitionStart) * Double(step) / Double(steps)
                    let gains = LoopCrossfadeController.gains(
                        at: progress
                    )
                    graph.instanceWeights[outgoing] = gains.outgoing
                    graph.instanceWeights[incoming] = gains.incoming
                    graph.players[outgoing].volume = gains.outgoing * graph.envelope
                    graph.players[incoming].volume = gains.incoming * graph.envelope
                    if step < steps {
                        do {
                            try await Task.sleep(
                                nanoseconds: UInt64(
                                    remainingOverlap / Double(steps) * 1_000_000_000
                                )
                            )
                        } catch { return }
                    }
                }
                graph.players[outgoing].stop()
                graph.primaryIndex = incoming
                graph.instanceWeights[outgoing] = 0
                graph.instanceWeights[incoming] = 1
                transitionStart = 0
                // The incoming player has already advanced by `overlap` during
                // the transition. Wake again when it reaches its own overlap.
                delay = max(sourceDuration - 2 * overlap, 0)
            }
        }
    }

    private func stopClip(_ id: UUID) {
        crossfadeTasks[id]?.cancel()
        crossfadeTasks[id] = nil
        guard let graph = clips[id] else { return }
        graph.players.forEach { $0.stop() }
        graph.primaryIndex = 0
        graph.instanceWeights = graph.players.indices.map { $0 == 0 ? 1 : 0 }
    }

    private func clipEnvelope(for clip: SceneAudioClip, at time: Double) -> Float {
        var value = 1.0
        if clip.fadeInMilliseconds > 0 {
            value = min(
                value,
                max(time - clip.startSeconds, 0) / (Double(clip.fadeInMilliseconds) / 1000)
            )
        }
        if clip.fadeOutMilliseconds > 0 {
            value = min(
                value,
                max(clip.endSeconds - time, 0) / (Double(clip.fadeOutMilliseconds) / 1000)
            )
        }
        return Float(min(max(value, 0), 1))
    }

    private func prepareEnvironment() {
        _ = engine.mainMixerNode
        _ = engine.outputNode
        if !engine.attachedNodes.contains(environment) {
            engine.attach(environment)
            engine.connect(environment, to: engine.mainMixerNode, format: nil)
        }
        SpatialMixMapping.configureEnvironment(environment)
    }

    private func cancelCrossfades() {
        crossfadeTasks.values.forEach { $0.cancel() }
        crossfadeTasks = [:]
    }

    private func tearDownGraph() {
        cancelCrossfades()
        if engine.isRunning { engine.stop() }
        for graph in clips.values {
            for node in graph.players where engine.attachedNodes.contains(node) {
                engine.disconnectNodeOutput(node)
                engine.detach(node)
            }
            for unit in graph.masteringUnits where engine.attachedNodes.contains(unit) {
                engine.disconnectNodeOutput(unit)
                engine.detach(unit)
            }
        }
        for graph in groups.values where engine.attachedNodes.contains(graph.mixer) {
            engine.disconnectNodeOutput(graph.mixer)
            engine.detach(graph.mixer)
        }
        groups = [:]
        clips = [:]
        activeClipIDs = []
        nextEnvironmentInputBus = 0
        layerFadeMultipliers = [:]
        if engine.attachedNodes.contains(environment) {
            engine.disconnectNodeOutput(environment)
            engine.detach(environment)
        }
        engine.reset()
    }
}
