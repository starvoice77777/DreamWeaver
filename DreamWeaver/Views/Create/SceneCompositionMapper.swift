import AVFoundation
import CoreGraphics
import Foundation

/// Maps Create editor state ↔ `scene_composition_v1` for local reopen / remote draft sync.
enum SceneCompositionMapper {
    static func duration(for timeline: APIContentDTO.SceneTimeline) -> Double {
        if let hinted = timeline.duration_hint_seconds, hinted > 0 {
            return Double(hinted)
        }
        return max(timedActions(from: timeline).map(\.time).max() ?? 0, 120)
    }

    /// Converts every authored playback interval into an independently editable
    /// clip. Repeated loop sections and individual phrases therefore retain
    /// their real entry/exit times instead of collapsing into one 120-second row.
    static func editorSources(
        from timeline: APIContentDTO.SceneTimeline,
        scene: DreamScene
    ) -> [SpatialEditorSource] {
        let sceneDuration = duration(for: timeline)
        let events = timedActions(from: timeline)
        let phraseByID = Dictionary(uniqueKeysWithValues: timeline.phrases.map { ($0.id, $0) })
        let sourceByID = Dictionary(uniqueKeysWithValues: scene.soundSources.map { ($0.id, $0) })

        var positionsByTrack: [UUID: [TimedPosition]] = [:]
        for source in scene.soundSources {
            positionsByTrack[source.id] = [
                TimedPosition(time: 0, position: source.position)
            ]
        }
        for event in events where event.action.type == "set_position" {
            guard let trackID = resolvedTrackID(for: event.action, phrases: phraseByID),
                  let angle = event.action.angle,
                  let radius = event.action.radius else { continue }
            positionsByTrack[trackID, default: []].append(
                TimedPosition(
                    time: event.time,
                    position: SpatialPosition(angle: angle, radius: radius)
                )
            )
        }
        for id in positionsByTrack.keys {
            positionsByTrack[id]?.sort { $0.time < $1.time }
        }

        let oneShotKeys = Set(events.compactMap { event -> ActivationKey? in
            guard event.action.type == "play_oneshot" || event.action.type == "play_phrase",
                  let trackID = resolvedTrackID(for: event.action, phrases: phraseByID) else {
                return nil
            }
            return ActivationKey(trackID: trackID, time: event.time)
        })

        var activeStarts: [UUID: Double] = [:]
        var segments: [ImportedSegment] = []
        var usedSegmentIDs: Set<UUID> = []

        func nextSegmentID(preferred: UUID?) -> UUID {
            if let preferred, usedSegmentIDs.insert(preferred).inserted {
                return preferred
            }
            var generated = UUID()
            while !usedSegmentIDs.insert(generated).inserted {
                generated = UUID()
            }
            return generated
        }

        func closeContinuous(trackID: UUID, at end: Double) {
            guard let start = activeStarts.removeValue(forKey: trackID),
                  end > start + 0.01,
                  let source = sourceByID[trackID] else { return }
            segments.append(
                ImportedSegment(
                    id: nextSegmentID(preferred: trackID),
                    trackID: trackID,
                    name: source.name,
                    resourceName: source.resourceName,
                    start: start,
                    end: min(end, sceneDuration),
                    isLooping: true
                )
            )
        }

        for event in events {
            let action = event.action
            guard let trackID = resolvedTrackID(for: action, phrases: phraseByID),
                  let source = sourceByID[trackID] else { continue }

            switch action.type {
            case "pause", "disable":
                closeContinuous(trackID: trackID, at: event.time)
            case "enable":
                let key = ActivationKey(trackID: trackID, time: event.time)
                if source.layer != .voice,
                   source.layer != .trigger,
                   !oneShotKeys.contains(key),
                   activeStarts[trackID] == nil {
                    activeStarts[trackID] = event.time
                }
            case "play":
                if activeStarts[trackID] == nil {
                    activeStarts[trackID] = event.time
                }
            case "play_oneshot", "play_phrase":
                let phrase = action.phrase_id.flatMap { phraseByID[$0] }
                let resourceName = action.resource_key
                    ?? phrase?.voice_binding.resource_key
                    ?? source.resourceName
                let clipDuration = bundledDuration(forResource: resourceName)
                    ?? (action.type == "play_phrase" ? 4 : 5)
                let boundaryTypes: Set<String> = [
                    "enable", "play", "play_phrase", "play_oneshot", "pause", "disable"
                ]
                let authoredBoundary = events.first { candidate in
                    candidate.time > event.time + 0.001
                        && boundaryTypes.contains(candidate.action.type)
                        && resolvedTrackID(
                            for: candidate.action,
                            phrases: phraseByID
                        ) == trackID
                }?.time
                let end = min(
                    max(event.time + max(clipDuration, 1), event.time + 1),
                    authoredBoundary ?? sceneDuration,
                    sceneDuration
                )
                segments.append(
                    ImportedSegment(
                        id: nextSegmentID(preferred: phrase?.id),
                        trackID: trackID,
                        name: phrase?.text ?? source.name,
                        resourceName: resourceName,
                        start: event.time,
                        end: end,
                        isLooping: false
                    )
                )
            default:
                break
            }
        }
        for trackID in Array(activeStarts.keys) {
            closeContinuous(trackID: trackID, at: sceneDuration)
        }

        return segments
            .filter { $0.start < sceneDuration && $0.end > $0.start }
            .sorted {
                if abs($0.start - $1.start) > 0.001 { return $0.start < $1.start }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            .compactMap { segment in
                guard let source = sourceByID[segment.trackID] else { return nil }
                let positions = positionsByTrack[segment.trackID] ?? [
                    TimedPosition(time: 0, position: source.position)
                ]
                let startPosition = positions.last(where: { $0.time <= segment.start })?.position
                    ?? source.position
                var keyPoints = [
                    SpatialKeyPoint(
                        time: segment.start,
                        position: point(
                            angle: startPosition.angle,
                            radius: startPosition.radius
                        ),
                        createdByUser: false
                    )
                ]
                keyPoints.append(contentsOf: positions.compactMap { item in
                    guard item.time > segment.start + 0.001,
                          item.time <= segment.end + 0.001 else { return nil }
                    return SpatialKeyPoint(
                        time: item.time,
                        position: point(angle: item.position.angle, radius: item.position.radius),
                        createdByUser: false
                    )
                })
                let material = material(forResourceKey: segment.resourceName)
                    ?? material(for: source)
                return SpatialEditorSource(
                    id: segment.id,
                    materialID: material?.id,
                    // Official phrase actions may reuse one voice track/asset while
                    // selecting a different bundled resource for every sentence.
                    // Keep the exact resource authoritative or all imported phrases
                    // collapse back to the seed asset on the next save/reopen.
                    assetID: segment.resourceName == nil ? source.assetId : nil,
                    resourceName: segment.resourceName,
                    name: segment.name,
                    iconName: source.symbolName,
                    theme: material?.theme ?? theme(forLayer: source.layer.rawValue),
                    defaultPosition: keyPoints[0].position,
                    keyPoints: keyPoints,
                    audioStartTime: segment.start,
                    audioDuration: segment.end - segment.start,
                    isLooping: segment.isLooping,
                    isVoice: source.layer == .voice
                )
            }
    }

    static func textCues(
        from timeline: APIContentDTO.SceneTimeline
    ) -> [SpatialTextCue] {
        let phraseByID = Dictionary(uniqueKeysWithValues: timeline.phrases.map { ($0.id, $0) })
        var usedIDs: Set<UUID> = []
        return timedActions(from: timeline).compactMap { event in
            guard event.action.type == "play_phrase",
                  let phraseID = event.action.phrase_id,
                  let phrase = phraseByID[phraseID] else { return nil }
            let id = usedIDs.insert(phraseID).inserted ? phraseID : UUID()
            return SpatialTextCue(id: id, time: event.time, text: phrase.text)
        }
    }

    static func composition(
        from sources: [SpatialEditorSource],
        duration: Double,
        textCues: [SpatialTextCue] = []
    ) -> APIContentDTO.SceneComposition {
        let tracks = sources.map { source -> APIContentDTO.CompositionTrack in
            let start = max(0, source.audioStartTime)
            let end = max(start + 1, min(source.audioEndTime, duration))
            let keyframes = normalizedKeyframes(for: source, start: start, end: end)
            return APIContentDTO.CompositionTrack(
                id: source.id,
                asset_id: source.assetID,
                resource_key: source.assetID == nil ? resourceKey(for: source) : nil,
                layer: layer(for: source),
                loop: source.isLooping ?? !source.isVoice,
                start_seconds: start,
                end_seconds: end,
                source_duration_seconds: source.audioDuration,
                keyframes: keyframes
            )
        }
        let durationSeconds = tracks.map(\.end_seconds).max() ?? duration
        let cues: [APIContentDTO.CompositionTextCue]? = textCues.isEmpty
            ? nil
            : textCues.map {
                APIContentDTO.CompositionTextCue(id: $0.id, time: $0.time, text: $0.text)
            }
        return APIContentDTO.SceneComposition(
            schema: "scene_composition_v1",
            version: 1,
            duration_seconds: durationSeconds,
            tracks: tracks,
            text_cues: cues
        )
    }

    static func textCues(
        from composition: APIContentDTO.SceneComposition
    ) -> [SpatialTextCue] {
        (composition.text_cues ?? []).map {
            SpatialTextCue(id: $0.id, time: $0.time, text: $0.text)
        }
        .sorted { $0.time < $1.time }
    }

    static func editorSources(
        from composition: APIContentDTO.SceneComposition
    ) -> [SpatialEditorSource] {
        composition.tracks.map { track in
            let material = material(forResourceKey: track.resource_key)
            let defaultPoint: CGPoint = {
                if let first = track.keyframes.first {
                    return point(angle: first.angle, radius: first.radius)
                }
                return material?.defaultPosition ?? .zero
            }()
            let keyPoints = track.keyframes.map { frame in
                SpatialKeyPoint(
                    time: frame.t,
                    position: point(angle: frame.angle, radius: frame.radius),
                    createdByUser: true
                )
            }
            let start = track.start_seconds
            let end = max(track.end_seconds, start + 1)
            return SpatialEditorSource(
                id: track.id,
                materialID: material?.id,
                assetID: track.asset_id,
                resourceName: track.asset_id == nil ? track.resource_key : nil,
                name: material?.name ?? (track.resource_key ?? "声源"),
                iconName: material?.iconName ?? "waveform",
                theme: material?.theme ?? theme(forLayer: track.layer),
                defaultPosition: defaultPoint,
                keyPoints: keyPoints.isEmpty
                    ? [SpatialKeyPoint(time: start, position: defaultPoint, createdByUser: true)]
                    : keyPoints,
                audioStartTime: start,
                audioDuration: end - start,
                isLooping: track.loop,
                isVoice: material?.isVoice == true || track.layer == "voice"
            )
        }
    }

    static func resourceKey(for source: SpatialEditorSource) -> String {
        if let resourceName = source.resourceName, !resourceName.isEmpty {
            return resourceName
        }
        switch source.materialID {
        case "rain": return "rain_soft"
        case "wind": return "wind_realistic"
        case "bamboo": return "rain_bamboo_leaf"
        case "voice": return "voice_phrase_01"
        // Bundle currently ships rain/wind/bamboo/stream/towel/voice/hair*; map others to closest loops.
        case "piano": return "stream_nature"
        case "insect": return "rain_bamboo_leaf"
        case "tide", "stream": return "stream_nature"
        case "towel": return "hair_towel"
        case let id?: return "create_\(id)"
        case nil: return "create_custom"
        }
    }

    /// Flat `SoundSource` list for Create editor preview (LocalPlaybackService).
    static func playbackSources(
        from sources: [SpatialEditorSource],
        at time: Double
    ) -> [SoundSource] {
        sources.compactMap { source in
            let key = source.resourceName ?? resourceKey(for: source)
            guard !key.hasPrefix("create_") else { return nil }
            let point = SpatialTrajectory.position(at: time, source: source)
            let radius = min(max(hypot(point.x, point.y), 0), 1)
            let angle = atan2(point.x, -point.y)
            let inWindow = time >= source.audioStartTime && time < source.audioEndTime
            return SoundSource(
                id: source.id,
                name: source.name,
                symbolName: source.iconName,
                isEnabled: inWindow,
                initialEnvelope: inWindow ? 1 : 0,
                position: SpatialPosition(angle: angle, radius: radius),
                resourceName: key,
                // Preview uses continuous players; official `.voice` oneshots need a timeline.
                layer: .ambience
            )
        }
    }

    private static func layer(for source: SpatialEditorSource) -> String {
        if source.isVoice { return "voice" }
        switch source.theme {
        case .narration:
            return "voice"
        case .texture:
            return "trigger"
        case .water, .rain, .wind, .music, .fire, .nature:
            return "ambience"
        }
    }

    private static func theme(forLayer layer: String?) -> SpatialSourceTheme {
        switch layer {
        case "voice": return .narration
        case "trigger": return .texture
        case "environment": return .rain
        default: return .wind
        }
    }

    private static func material(forResourceKey key: String?) -> SpatialEditorMaterial? {
        guard let key else { return nil }
        let catalog = SpatialEditorMaterial.catalog
        switch key {
        case "rain_soft", "rain_parasol":
            return catalog.first { $0.id == "rain" }
        case "wind_realistic", "wind_gust":
            return catalog.first { $0.id == "wind" }
        case "rain_bamboo_leaf":
            return catalog.first { $0.id == "bamboo" }
        case let voiceKey where voiceKey == "voice_phrase_mom" || voiceKey.hasPrefix("voice_phrase_"):
            return catalog.first { $0.id == "voice" }
        case "stream_nature":
            return catalog.first { $0.id == "stream" }
        case "hair_towel":
            return catalog.first { $0.id == "towel" }
        case "fireplace_soft":
            return catalog.first { $0.id == "fire" }
        case "piano_soft":
            return catalog.first { $0.id == "piano" }
        case "insect_night":
            return catalog.first { $0.id == "insect" }
        default:
            if key.hasPrefix("create_") {
                let materialID = String(key.dropFirst("create_".count))
                return catalog.first { $0.id == materialID }
            }
            return nil
        }
    }

    private static func material(for source: SoundSource) -> SpatialEditorMaterial? {
        let catalog = SpatialEditorMaterial.catalog
        if source.layer == .voice { return catalog.first(where: \.isVoice) }
        let name = source.name.lowercased()
        let symbol = source.symbolName.lowercased()
        if name.contains("雨") || symbol.contains("rain") { return catalog.first { $0.id == "rain" } }
        if name.contains("风") || symbol.contains("wind") { return catalog.first { $0.id == "wind" } }
        if name.contains("毛巾") || symbol.contains("hand") { return catalog.first { $0.id == "towel" } }
        if name.contains("水") || name.contains("泡") || symbol.contains("drop") {
            return catalog.first { $0.id == "stream" }
        }
        return nil
    }

    private static func timedActions(
        from timeline: APIContentDTO.SceneTimeline
    ) -> [TimedAction] {
        let sceneDuration = Double(timeline.duration_hint_seconds ?? 2700)
        var result: [TimedAction] = []
        var order = 0
        for cue in timeline.cues {
            let start: Double
            if let progress = cue.progress {
                start = min(max(progress, 0), 1) * sceneDuration
            } else if let at = cue.at_seconds {
                start = max(at, 0)
            } else {
                continue
            }
            var times = [start]
            if let period = cue.repeat_every_seconds, period > 0 {
                times = []
                let until = min(cue.until_seconds ?? sceneDuration, sceneDuration)
                var time = start
                var guardCount = 0
                while time <= until + 0.001, guardCount < 500 {
                    times.append(time)
                    time += period
                    guardCount += 1
                }
            }
            for time in times {
                for action in cue.actions {
                    result.append(TimedAction(time: time, order: order, action: action))
                    order += 1
                }
            }
        }
        return result.sorted {
            if abs($0.time - $1.time) > 0.000_1 { return $0.time < $1.time }
            return $0.order < $1.order
        }
    }

    private static func resolvedTrackID(
        for action: APIContentDTO.CueAction,
        phrases: [UUID: APIContentDTO.Phrase]
    ) -> UUID? {
        action.track_id ?? action.phrase_id.flatMap { phrases[$0]?.voice_binding.track_id }
    }

    private static func bundledDuration(forResource resourceName: String?) -> Double? {
        guard let resourceName,
              let url = LocalPlaybackService.url(forResource: resourceName),
              let file = try? AVAudioFile(forReading: url),
              file.processingFormat.sampleRate > 0 else { return nil }
        return Double(file.length) / file.processingFormat.sampleRate
    }

    private static func normalizedKeyframes(
        for source: SpatialEditorSource,
        start: Double,
        end: Double
    ) -> [APIContentDTO.CompositionKeyframe] {
        let points = SpatialTrajectory.flattenedKeyPoints(for: source)
        var frames: [APIContentDTO.CompositionKeyframe] = []
        var lastT: Double?

        let ensured: [SpatialKeyPoint]
        if points.isEmpty {
            ensured = [
                SpatialKeyPoint(time: start, position: source.defaultPosition, createdByUser: true)
            ]
        } else {
            ensured = points
        }

        for point in ensured {
            var t = min(max(point.time, start), end)
            if let lastT, t <= lastT {
                t = min(lastT + 0.05, end)
                if t <= lastT { continue }
            }
            let polar = polar(from: point.position)
            frames.append(
                APIContentDTO.CompositionKeyframe(
                    t: t,
                    angle: polar.angle,
                    radius: polar.radius
                )
            )
            lastT = t
        }

        if frames.isEmpty {
            let polar = polar(from: source.defaultPosition)
            frames = [
                APIContentDTO.CompositionKeyframe(
                    t: start,
                    angle: polar.angle,
                    radius: polar.radius
                )
            ]
        }
        return frames
    }

    /// Canvas coords match the shared API contract: 0 is front / screen-up.
    private static func polar(from point: CGPoint) -> (angle: Double, radius: Double) {
        let radius = min(max(hypot(point.x, point.y), 0), 1)
        let angle = atan2(point.x, -point.y)
        return (angle, radius)
    }

    private static func point(angle: Double, radius: Double) -> CGPoint {
        let r = min(max(radius, 0), 1)
        return CGPoint(x: sin(angle) * r, y: -cos(angle) * r)
    }

    private struct TimedAction {
        let time: Double
        let order: Int
        let action: APIContentDTO.CueAction
    }

    private struct TimedPosition {
        let time: Double
        let position: SpatialPosition
    }

    private struct ActivationKey: Hashable {
        let trackID: UUID
        let time: Double
    }

    private struct ImportedSegment {
        let id: UUID
        let trackID: UUID
        let name: String
        let resourceName: String?
        let start: Double
        let end: Double
        let isLooping: Bool
    }
}
