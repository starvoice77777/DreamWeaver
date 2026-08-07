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
        var lastAppliedPosition: SpatialPosition?

        init(group: SceneSourceGroup) {
            self.group = group
        }
    }

    private final class ClipGraph {
        let clip: SceneAudioClip
        let loopBuffer: AVAudioPCMBuffer?
        let resourceURL: URL
        let players: [AVAudioPlayerNode]
        let masteringUnits: [AVAudioUnitEQ]
        var envelope: Float = 1

        init(
            clip: SceneAudioClip,
            loopBuffer: AVAudioPCMBuffer?,
            resourceURL: URL,
            players: [AVAudioPlayerNode],
            masteringUnits: [AVAudioUnitEQ]
        ) {
            self.clip = clip
            self.loopBuffer = loopBuffer
            self.resourceURL = resourceURL
            self.players = players
            self.masteringUnits = masteringUnits
        }
    }

    private let engine = AVAudioEngine()
    private let environment = AVAudioEnvironmentNode()
    private var plan: SceneRenderPlan?
    private var groups: [UUID: GroupGraph] = [:]
    private var clips: [UUID: ClipGraph] = [:]
    private var activeClipIDs: Set<UUID> = []
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
            graph.lastAppliedPosition = group.defaultPosition
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
                let loopBuffer: AVAudioPCMBuffer?
                if clip.playbackMode == .oneshot {
                    loopBuffer = nil
                } else if let cached = buffersByResource[
                    loopBufferCacheKey(resource: resource, clip: clip)
                ] {
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
                    let prepared = seamlessLoopBuffer(
                        from: monoBuffer(from: loaded),
                        crossfadeMilliseconds: clip.crossfadeMilliseconds
                    )
                    buffersByResource[
                        loopBufferCacheKey(resource: resource, clip: clip)
                    ] = prepared
                    loopBuffer = prepared
                }
                // Crossfade loops are precomposed into one sample-continuous
                // buffer. Starting/stopping A/B nodes from the main actor made
                // every seam vulnerable to UI stalls on a real device.
                let instanceCount = 1
                let playbackFormat = loopBuffer?.format ?? file.processingFormat
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
                    engine.connect(player, to: mastering, format: playbackFormat)
                    engine.connect(
                        mastering,
                        to: group.mixer,
                        fromBus: 0,
                        toBus: group.nextInputBus,
                        format: playbackFormat
                    )
                    group.nextInputBus += 1
                    players.append(player)
                    masteringUnits.append(mastering)
                }
                clips[clip.id] = ClipGraph(
                    clip: clip,
                    loopBuffer: loopBuffer,
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
        for graph in clips.values {
            graph.players.forEach { $0.pause() }
        }
    }

    func stop() {
        isPlaying = false
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
            if shouldApplyPosition(sourceState.position, previous: group.lastAppliedPosition) {
                // Rendering algorithm/source mode are graph configuration and
                // must not be reassigned at 60 Hz. Doing so caused short HRTF
                // rebuilds that sounded like a loop glitch or bearing jump.
                SpatialMixMapping.applySourcePosition(
                    to: group.mixer,
                    position: sourceState.position
                )
                group.lastAppliedPosition = sourceState.position
            }
            let layerFade = Double(layerFadeMultipliers[group.group.layer] ?? 1)
            let gain = group.isEnabled
                ? sourceState.radialGain * sourceState.automationGain * layerFade
                : 0
            group.mixer.outputVolume = Float(min(max(gain, 0), 1))
        }

        for id in state.activeClipIDs {
            guard let graph = clips[id] else { continue }
            graph.envelope = clipEnvelope(for: graph.clip, at: state.time)
            for player in graph.players {
                player.volume = graph.envelope
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
        guard let loopBuffer = graph.loopBuffer else { return }
        let primary = graph.players[0]
        primary.volume = graph.envelope
        let loopDuration = Double(loopBuffer.frameLength) / loopBuffer.format.sampleRate
        let phase = loopDuration > 0 ? offset.truncatingRemainder(dividingBy: loopDuration) : 0
        scheduleRepeating(graph, player: primary, phase: phase)
    }

    private func scheduleRepeating(
        _ graph: ClipGraph,
        player: AVAudioPlayerNode,
        phase: Double
    ) {
        guard let buffer = graph.loopBuffer else { return }
        let scheduledBuffer = rotatedLoopBuffer(buffer, startingAtSeconds: phase)
        player.scheduleBuffer(
            scheduledBuffer,
            at: nil,
            options: .loops,
            completionHandler: nil
        )
        player.play()
    }

    private func stopClip(_ id: UUID) {
        guard let graph = clips[id] else { return }
        graph.players.forEach { $0.stop() }
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

    private func tearDownGraph() {
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

    private func loopBufferCacheKey(resource: String, clip: SceneAudioClip) -> String {
        "\(resource)#crossfade=\(clip.crossfadeMilliseconds)"
    }

    /// Spatial beds must enter AVAudioEnvironmentNode as true mono sources.
    /// Downmix explicitly instead of relying on graph format negotiation; a
    /// stereo rain master can otherwise leak its own momentary left/right image.
    private func monoBuffer(from source: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        guard source.format.channelCount > 1,
              let sourceChannels = source.floatChannelData,
              let monoFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: source.format.sampleRate,
                channels: 1,
                interleaved: false
              ), let output = AVAudioPCMBuffer(
                pcmFormat: monoFormat,
                frameCapacity: source.frameLength
              ), let outputChannel = output.floatChannelData?[0] else {
            return source
        }
        output.frameLength = source.frameLength
        let channelCount = Int(source.format.channelCount)
        let scale = Float(1) / Float(channelCount)
        for frame in 0..<Int(source.frameLength) {
            var sample: Float = 0
            for channel in 0..<channelCount {
                sample += sourceChannels[channel][frame]
            }
            outputChannel[frame] = sample * scale
        }
        return output
    }

    private func shouldApplyPosition(
        _ position: SpatialPosition,
        previous: SpatialPosition?
    ) -> Bool {
        guard let previous else { return true }
        return abs(
            SpatialTrajectoryEvaluator.shortestAngleDelta(
                from: previous.angle,
                to: position.angle
            )
        ) > 0.000_01 || abs(previous.radius - position.radius) > 0.000_01
    }

    /// Produces one loop whose boundary is already an equal-power blend of
    /// the source tail and head. AVAudioPlayerNode can then repeat it with the
    /// sample-accurate `.loops` option; no wall-clock task participates in a seam.
    private func seamlessLoopBuffer(
        from source: AVAudioPCMBuffer,
        crossfadeMilliseconds: Int
    ) -> AVAudioPCMBuffer {
        let sourceDuration = Double(source.frameLength) / source.format.sampleRate
        let overlapSeconds = LoopCrossfadeController.validatedDuration(
            milliseconds: crossfadeMilliseconds,
            sourceDurationSeconds: sourceDuration
        )
        let overlapFrames = min(
            AVAudioFrameCount((overlapSeconds * source.format.sampleRate).rounded()),
            source.frameLength / 2
        )
        guard overlapFrames > 1,
              source.frameLength > overlapFrames * 2,
              let sourceChannels = source.floatChannelData else {
            return source
        }

        let outputLength = source.frameLength - overlapFrames
        guard let output = AVAudioPCMBuffer(
            pcmFormat: source.format,
            frameCapacity: outputLength
        ), let outputChannels = output.floatChannelData else {
            return source
        }
        output.frameLength = outputLength

        let channelCount = Int(source.format.channelCount)
        let overlapCount = Int(overlapFrames)
        let sourceCount = Int(source.frameLength)
        let outputCount = Int(outputLength)
        let middleCount = outputCount - overlapCount

        for channel in 0..<channelCount {
            let input = sourceChannels[channel]
            let target = outputChannels[channel]
            for frame in 0..<overlapCount {
                let progress = Double(frame) / Double(overlapCount - 1)
                let gains = LoopCrossfadeController.gains(at: progress)
                target[frame] = input[sourceCount - overlapCount + frame] * gains.outgoing
                    + input[frame] * gains.incoming
            }
            if middleCount > 0 {
                target.advanced(by: overlapCount).update(
                    from: input.advanced(by: overlapCount),
                    count: middleCount
                )
            }
        }
        return output
    }

    /// Rotates a prepared seamless loop so resume/seek begins at the requested
    /// phase without scheduling a non-crossfaded file tail in front of it.
    private func rotatedLoopBuffer(
        _ source: AVAudioPCMBuffer,
        startingAtSeconds phase: Double
    ) -> AVAudioPCMBuffer {
        let frameCount = Int(source.frameLength)
        guard phase > 0,
              frameCount > 1,
              let sourceChannels = source.floatChannelData else {
            return source
        }
        let start = min(
            max(Int((phase * source.format.sampleRate).rounded()), 0),
            frameCount - 1
        )
        guard start > 0,
              let output = AVAudioPCMBuffer(
                pcmFormat: source.format,
                frameCapacity: source.frameLength
              ), let outputChannels = output.floatChannelData else {
            return source
        }
        output.frameLength = source.frameLength

        for channel in 0..<Int(source.format.channelCount) {
            let input = sourceChannels[channel]
            let target = outputChannels[channel]
            let tailCount = frameCount - start
            target.update(from: input.advanced(by: start), count: tailCount)
            target.advanced(by: tailCount).update(from: input, count: start)
        }
        return output
    }
}
