import AVFoundation
import CoreGraphics
import Foundation

/// Maps Create editor state ↔ `scene_composition_v2` with v1 read compatibility.
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
                TimedPosition(time: 0, order: -1, position: source.position)
            ]
        }
        for event in events where event.action.type == "set_position" {
            guard let trackID = resolvedTrackID(for: event.action, phrases: phraseByID),
                  let angle = event.action.angle,
                  let radius = event.action.radius else { continue }
            positionsByTrack[trackID, default: []].append(
                TimedPosition(
                    time: event.time,
                    order: event.order,
                    position: SpatialPosition(angle: angle, radius: radius)
                )
            )
        }
        for id in positionsByTrack.keys {
            let ordered = (positionsByTrack[id] ?? []).sorted { lhs, rhs in
                if abs(lhs.time - rhs.time) > 0.000_1 { return lhs.time < rhs.time }
                return lhs.order < rhs.order
            }
            var unique: [TimedPosition] = []
            for item in ordered {
                if let last = unique.last, abs(last.time - item.time) < 0.000_1 {
                    unique[unique.count - 1] = item
                } else {
                    unique.append(item)
                }
            }
            positionsByTrack[id] = unique
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

        func nextSegmentID(preferred: UUID?, trackID: UUID, time: Double) -> UUID {
            if let preferred, usedSegmentIDs.insert(preferred).inserted {
                return preferred
            }
            var bytes = trackID.uuid
            var timeBits = UInt64(max((time * 1000).rounded(), 0)).littleEndian
            withUnsafeBytes(of: &timeBits) { raw in
                withUnsafeMutableBytes(of: &bytes) { target in
                    for index in 0..<min(raw.count, 8) {
                        target[index + 8] ^= raw[index]
                    }
                    target[6] = (target[6] & 0x0F) | 0x50
                    target[8] = (target[8] & 0x3F) | 0x80
                }
            }
            var generated = UUID(uuid: bytes)
            while !usedSegmentIDs.insert(generated).inserted {
                withUnsafeMutableBytes(of: &bytes) { raw in
                    raw[15] &+= 1
                }
                generated = UUID(uuid: bytes)
            }
            return generated
        }

        func closeContinuous(trackID: UUID, at end: Double) {
            guard let start = activeStarts.removeValue(forKey: trackID),
                  end > start + 0.01,
                  let source = sourceByID[trackID] else { return }
            segments.append(
                ImportedSegment(
                    id: nextSegmentID(preferred: trackID, trackID: trackID, time: start),
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
                        id: nextSegmentID(
                            preferred: phrase?.id,
                            trackID: trackID,
                            time: event.time
                        ),
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
                // Position belongs to the SourceGroup, not this clip window.
                // Keep the complete authored curve on every compatibility row;
                // v2 persistence de-duplicates it back to one group curve.
                let keyPoints = positions.map { item in
                    SpatialKeyPoint(
                        time: item.time,
                        position: point(angle: item.position.angle, radius: item.position.radius),
                        createdByUser: false,
                        interpolation: .linear
                    )
                }
                let material = material(forResourceKey: segment.resourceName)
                    ?? material(for: source)
                return SpatialEditorSource(
                    id: segment.id,
                    sourceGroupID: segment.trackID,
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
                    crossfadeMilliseconds: segment.isLooping
                        ? LoopCrossfadeController.preferredMilliseconds(
                            for: segment.resourceName
                        )
                        : 0,
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
        let clips = sources.map { source -> APIContentDTO.CompositionClip in
            let safeDuration = max(duration, 1)
            let start = min(max(0, source.audioStartTime), safeDuration - 1)
            let end = min(max(start + 1, source.audioEndTime), safeDuration)
            return APIContentDTO.CompositionClip(
                id: source.id,
                source_group_id: source.effectiveSourceGroupID,
                asset_id: source.assetID,
                resource_key: source.resourceName
                    ?? (source.assetID == nil ? resourceKey(for: source) : nil),
                start_seconds: start,
                end_seconds: end,
                source_offset_seconds: source.sourceOffsetSeconds,
                playback_mode: playbackMode(for: source).rawValue,
                crossfade_ms: source.crossfadeMilliseconds,
                fade_in_ms: source.fadeInMilliseconds,
                fade_out_ms: source.fadeOutMilliseconds,
                phrase_id: source.isVoice ? source.id : nil,
                text_cue_id: nil,
                mastering_profile_key: source.resourceName
            )
        }
        let groups = Dictionary(grouping: sources, by: \.effectiveSourceGroupID)
            .compactMap { groupID, members -> APIContentDTO.CompositionSourceGroup? in
                guard let representative = members.first else { return nil }
                let groupFrames = mergedGroupKeyframes(from: members, duration: duration)
                return APIContentDTO.CompositionSourceGroup(
                    id: groupID,
                    name: groupName(for: members),
                    symbol_name: representative.iconName,
                    layer: layer(for: representative),
                    display_policy: representative.isVoice
                        ? SourceGroupDisplayPolicy.alwaysInWindow.rawValue
                        : SourceGroupDisplayPolicy.selectedOrActive.rawValue,
                    position_keyframes: groupFrames
                )
            }
            .sorted { $0.id.uuidString < $1.id.uuidString }
        let durationSeconds = max(
            max(duration, clips.map(\.end_seconds).max() ?? 0),
            1
        )
        let cues: [APIContentDTO.CompositionTextCue]? = textCues.isEmpty
            ? nil
            : textCues.map {
                APIContentDTO.CompositionTextCue(id: $0.id, time: $0.time, text: $0.text)
            }
        return APIContentDTO.SceneComposition(
            schema: "scene_composition_v2",
            version: 1,
            duration_seconds: durationSeconds,
            tracks: [],
            source_groups: groups,
            clips: clips,
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
        if composition.schema == "scene_composition_v2",
           let groups = composition.source_groups,
           let clips = composition.clips {
            let groupsByID = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0) })
            return clips.compactMap { clip in
                guard let group = groupsByID[clip.source_group_id] else { return nil }
                let material = material(forResourceKey: clip.resource_key)
                let frames = group.position_keyframes
                let defaultPoint = frames.first.map {
                    point(angle: $0.angle, radius: $0.radius)
                } ?? material?.defaultPosition ?? .zero
                return SpatialEditorSource(
                    id: clip.id,
                    sourceGroupID: group.id,
                    materialID: material?.id,
                    assetID: clip.asset_id,
                    resourceName: clip.resource_key,
                    name: material?.name ?? group.name,
                    iconName: group.symbol_name ?? material?.iconName ?? "waveform",
                    theme: material?.theme ?? theme(forLayer: group.layer),
                    defaultPosition: defaultPoint,
                    keyPoints: frames.map {
                        SpatialKeyPoint(
                            time: $0.t,
                            position: point(angle: $0.angle, radius: $0.radius),
                            createdByUser: true,
                            interpolation: SceneInterpolationMode(rawValue: $0.interpolation ?? "")
                                ?? .smoothstep
                        )
                    },
                    audioStartTime: clip.start_seconds,
                    audioDuration: max(clip.end_seconds - clip.start_seconds, 1),
                    isLooping: clip.playback_mode != ScenePlaybackMode.oneshot.rawValue,
                    sourceOffsetSeconds: clip.source_offset_seconds ?? 0,
                    crossfadeMilliseconds: clip.crossfade_ms ?? 0,
                    fadeInMilliseconds: clip.fade_in_ms ?? 0,
                    fadeOutMilliseconds: clip.fade_out_ms ?? 0,
                    isVoice: group.layer == AudioLayerKind.voice.rawValue
                )
            }
        }
        return composition.tracks.map { track in
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
                    createdByUser: true,
                    interpolation: SceneInterpolationMode(rawValue: frame.interpolation ?? "")
                        ?? .smoothstep
                )
            }
            let start = track.start_seconds
            let end = max(track.end_seconds, start + 1)
            return SpatialEditorSource(
                id: track.id,
                sourceGroupID: track.id,
                materialID: material?.id,
                assetID: track.asset_id,
                resourceName: track.resource_key,
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

    private static func playbackMode(for source: SpatialEditorSource) -> ScenePlaybackMode {
        guard source.isLooping ?? !source.isVoice else { return .oneshot }
        return .boundedLoop
    }

    private static func groupName(for members: [SpatialEditorSource]) -> String {
        if members.contains(where: \.isVoice) { return "轻声陪伴" }
        return members.first?.name ?? "声源"
    }

    private static func mergedGroupKeyframes(
        from members: [SpatialEditorSource],
        duration: Double
    ) -> [APIContentDTO.CompositionKeyframe] {
        let points = members.flatMap { SpatialTrajectory.flattenedKeyPoints(for: $0) }
            .map { point in
                var clamped = point
                clamped.time = min(max(point.time, 0), duration)
                return clamped
            }
            .sorted { $0.time < $1.time }
        var deduplicated: [SpatialKeyPoint] = []
        for point in points {
            if let last = deduplicated.last, abs(last.time - point.time) < 0.001 {
                deduplicated[deduplicated.count - 1] = point
            } else {
                deduplicated.append(point)
            }
        }
        if deduplicated.isEmpty, let source = members.first {
            deduplicated = [
                SpatialKeyPoint(time: 0, position: source.defaultPosition, createdByUser: false)
            ]
        }
        return deduplicated.map { point in
            let polar = polar(from: point.position)
            return APIContentDTO.CompositionKeyframe(
                t: point.time,
                angle: polar.angle,
                radius: polar.radius,
                interpolation: (point.interpolation ?? .smoothstep).rawValue
            )
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
        let order: Int
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
