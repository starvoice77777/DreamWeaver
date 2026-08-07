import CoreGraphics
import Foundation

/// The only input boundary that turns persisted authoring formats into runtime
/// semantics. Playback code consumes `SceneRenderPlan`, never raw timeline cues.
enum ScenePlanCompiler {
    static func compile(
        composition: APIContentDTO.SceneComposition,
        sceneID: UUID
    ) -> SceneRenderPlan {
        if composition.schema == "scene_composition_v2",
           let rawGroups = composition.source_groups,
           let rawClips = composition.clips {
            let groups = rawGroups.map { raw in
                let frames = raw.position_keyframes.map(positionKeyframe)
                return SceneSourceGroup(
                    id: raw.id,
                    name: raw.name,
                    symbolName: normalizedSymbolName(raw.symbol_name),
                    layer: AudioLayerKind(rawValue: raw.layer) ?? .ambience,
                    displayPolicy: SourceGroupDisplayPolicy(rawValue: raw.display_policy ?? "")
                        ?? .selectedOrActive,
                    defaultPosition: frames.first?.position ?? .default,
                    positionKeyframes: frames
                )
            }
            let clips = rawClips.map { raw in
                SceneAudioClip(
                    id: raw.id,
                    sourceGroupID: raw.source_group_id,
                    assetID: raw.asset_id,
                    resourceKey: raw.resource_key,
                    startSeconds: raw.start_seconds,
                    endSeconds: raw.end_seconds,
                    sourceOffsetSeconds: raw.source_offset_seconds ?? 0,
                    playbackMode: ScenePlaybackMode(rawValue: raw.playback_mode) ?? .oneshot,
                    crossfadeMilliseconds: raw.crossfade_ms ?? 0,
                    fadeInMilliseconds: raw.fade_in_ms ?? 0,
                    fadeOutMilliseconds: raw.fade_out_ms ?? 0,
                    phraseID: raw.phrase_id,
                    textCueID: raw.text_cue_id,
                    masteringProfileKey: raw.mastering_profile_key
                )
            }
            return makePlan(
                sceneID: sceneID,
                duration: composition.duration_seconds ?? clips.map(\.endSeconds).max() ?? 0,
                groups: groups,
                clips: clips
            )
        }

        let groups = composition.tracks.map { track -> SceneSourceGroup in
            let frames = track.keyframes.map(positionKeyframe)
            return SceneSourceGroup(
                id: track.id,
                name: track.resource_key ?? "声源",
                symbolName: "waveform",
                layer: AudioLayerKind(rawValue: track.layer ?? "") ?? .ambience,
                defaultPosition: frames.first?.position ?? .default,
                positionKeyframes: frames
            )
        }
        let clips = composition.tracks.map { track in
            SceneAudioClip(
                id: track.id,
                sourceGroupID: track.id,
                assetID: track.asset_id,
                resourceKey: track.resource_key,
                startSeconds: track.start_seconds,
                endSeconds: track.end_seconds,
                playbackMode: track.loop == true ? .boundedLoop : .oneshot,
                crossfadeMilliseconds: LoopCrossfadeController.preferredMilliseconds(
                    for: track.resource_key
                ),
                masteringProfileKey: track.resource_key
            )
        }
        return makePlan(
            sceneID: sceneID,
            duration: composition.duration_seconds ?? clips.map(\.endSeconds).max() ?? 0,
            groups: groups,
            clips: clips
        )
    }

    static func compile(
        editorSources: [SpatialEditorSource],
        sceneID: UUID,
        duration: Double,
        baseScene: DreamScene? = nil
    ) -> SceneRenderPlan {
        let sourcesByGroup = Dictionary(grouping: editorSources, by: \.effectiveSourceGroupID)
        let baseByID = Dictionary(
            uniqueKeysWithValues: (baseScene?.soundSources ?? []).map { ($0.id, $0) }
        )
        let groups = sourcesByGroup.compactMap { groupID, members -> SceneSourceGroup? in
            guard let representative = members.first else { return nil }
            let base = baseByID[groupID]
            let frames = mergedPositionKeyframes(from: members)
            return SceneSourceGroup(
                id: groupID,
                name: base?.name ?? (representative.isVoice ? "轻声陪伴" : representative.name),
                symbolName: normalizedSymbolName(base?.symbolName ?? representative.iconName),
                layer: base?.layer ?? layer(for: representative),
                displayPolicy: representative.isVoice ? .alwaysInWindow : .selectedOrActive,
                defaultPosition: frames.first?.position ?? polar(from: representative.defaultPosition),
                positionKeyframes: frames
            )
        }
        let clips = editorSources.compactMap { source -> SceneAudioClip? in
            let key = source.resourceName ?? SceneCompositionMapper.resourceKey(for: source)
            guard source.assetID != nil || !key.hasPrefix("create_") else { return nil }
            let loops = source.isLooping ?? !source.isVoice
            return SceneAudioClip(
                id: source.id,
                sourceGroupID: source.effectiveSourceGroupID,
                assetID: source.assetID,
                resourceKey: source.resourceName ?? (source.assetID == nil ? key : nil),
                startSeconds: source.audioStartTime,
                endSeconds: min(source.audioEndTime, duration),
                sourceOffsetSeconds: source.sourceOffsetSeconds ?? 0,
                playbackMode: loops ? .boundedLoop : .oneshot,
                crossfadeMilliseconds: source.crossfadeMilliseconds
                    ?? (loops ? LoopCrossfadeController.preferredMilliseconds(for: key) : 0),
                fadeInMilliseconds: source.fadeInMilliseconds ?? 0,
                fadeOutMilliseconds: source.fadeOutMilliseconds ?? 0,
                phraseID: source.isVoice ? source.id : nil,
                masteringProfileKey: key
            )
        }
        return makePlan(sceneID: sceneID, duration: duration, groups: groups, clips: clips)
    }

    static func compile(timeline: APIContentDTO.SceneTimeline, scene: DreamScene) -> SceneRenderPlan {
        let sources = SceneCompositionMapper.editorSources(from: timeline, scene: scene)
        var plan = compile(
            editorSources: sources,
            sceneID: timeline.scene_id,
            duration: SceneCompositionMapper.duration(for: timeline),
            baseScene: scene
        )
        let baselines = Dictionary(
            uniqueKeysWithValues: scene.soundSources.map { ($0.id, $0.initialEnvelope) }
        )
        plan.automationCurves = automationCurves(
            from: timeline,
            groups: plan.sourceGroups,
            baselines: baselines
        )
        return plan
    }

    private static func makePlan(
        sceneID: UUID,
        duration: Double,
        groups: [SceneSourceGroup],
        clips: [SceneAudioClip]
    ) -> SceneRenderPlan {
        let events = clips.flatMap { clip in
            [
                SceneRenderEvent(
                    id: derivedUUID(namespace: clip.id, marker: 1),
                    time: clip.startSeconds,
                    action: .startClip,
                    clipID: clip.id
                ),
                SceneRenderEvent(
                    id: derivedUUID(namespace: clip.id, marker: 2),
                    time: clip.endSeconds,
                    action: .stopClip,
                    clipID: clip.id
                )
            ]
        }
        return SceneRenderPlan(
            sceneID: sceneID,
            durationSeconds: duration,
            sourceGroups: groups.sorted { $0.id.uuidString < $1.id.uuidString },
            clips: clips,
            events: events
        )
    }

    nonisolated private static func positionKeyframe(
        _ raw: APIContentDTO.CompositionKeyframe
    ) -> ScenePositionKeyframe {
        ScenePositionKeyframe(
            time: raw.t,
            position: SpatialPosition(angle: raw.angle, radius: raw.radius),
            interpolation: SceneInterpolationMode(rawValue: raw.interpolation ?? "") ?? .linear
        )
    }

    nonisolated private static func normalizedSymbolName(_ raw: String?) -> String {
        guard let value = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return "waveform"
        }
        return value
    }

    private static func mergedPositionKeyframes(
        from members: [SpatialEditorSource]
    ) -> [ScenePositionKeyframe] {
        let frames = members.flatMap { source in
            SpatialTrajectory.flattenedKeyPoints(for: source).map { point in
                ScenePositionKeyframe(
                    time: point.time,
                    position: polar(from: point.position),
                    interpolation: point.interpolation ?? ((source.motionClips ?? []).contains {
                        point.time >= $0.startTime && point.time <= $0.endTime
                    } ? .recordedLinear : .smoothstep)
                )
            }
        }
        var result: [ScenePositionKeyframe] = []
        for frame in frames.sorted(by: { $0.time < $1.time }) {
            if let last = result.last, abs(last.time - frame.time) < 0.001 {
                result[result.count - 1] = frame
            } else {
                result.append(frame)
            }
        }
        return result
    }

    private static func automationCurves(
        from timeline: APIContentDTO.SceneTimeline,
        groups: [SceneSourceGroup],
        baselines: [UUID: Double]
    ) -> [SceneAutomationCurve] {
        let validIDs = Set(groups.map(\.id))
        let phraseTracks = Dictionary(
            uniqueKeysWithValues: timeline.phrases.compactMap { phrase in
                phrase.voice_binding.track_id.map { (phrase.id, $0) }
            }
        )
        var pointsByGroup: [UUID: [SceneAutomationKeyframe]] = [:]
        for timed in expandedActions(from: timeline) {
            let action = timed.action
            guard ["set_envelope", "fade_in", "fade_out"].contains(action.type),
                  let id = action.track_id ?? action.phrase_id.flatMap({ phraseTracks[$0] }),
                  validIDs.contains(id) else { continue }
            let authoredTarget = action.type == "fade_out" ? 0 : (action.envelope ?? 1)
            let baseline = baselines[id] ?? 1
            let target: Double
            if authoredTarget <= 0 {
                target = 0
            } else if baseline > 0 {
                // Legacy steady-state envelope is normalized away: radius owns
                // loudness. Values below it remain meaningful duck/fade automation.
                target = min(max(authoredTarget / baseline, 0), 1)
            } else {
                target = 1
            }
            let duration = Double(action.fade_ms ?? 0) / 1000
            var points = (pointsByGroup[id] ?? []).sorted { $0.time < $1.time }
            let previous = SpatialTrajectoryEvaluator.automationValue(
                at: timed.time,
                keyframes: points,
                defaultValue: 1
            )
            // A new authored command supersedes the unfinished tail of an
            // earlier fade. Removing equal-time points also gives same-time
            // actions deterministic last-action-wins semantics.
            let supersedesFuture = points.contains { $0.time > timed.time + 0.000_1 }
            points.removeAll { $0.time >= timed.time - 0.000_1 }
            if !supersedesFuture,
               let lastIndex = points.indices.last,
               points[lastIndex].time < timed.time {
                points[lastIndex].interpolation = .hold
            } else if supersedesFuture,
                      duration == 0,
                      let last = points.last,
                      timed.time - last.time > 0.000_2 {
                // Preserve the audible value reached by the interrupted ramp
                // until immediately before an instantaneous replacement.
                points.append(
                    SceneAutomationKeyframe(
                        time: timed.time - 0.000_1,
                        value: previous,
                        interpolation: .hold
                    )
                )
            }
            if duration > 0 {
                points.append(
                    SceneAutomationKeyframe(
                        time: timed.time,
                        value: previous,
                        interpolation: .linear
                    )
                )
            }
            points.append(
                SceneAutomationKeyframe(
                    time: timed.time + duration,
                    value: min(max(target, 0), 1),
                    interpolation: .linear
                )
            )
            pointsByGroup[id] = points
        }
        return pointsByGroup.map { id, points in
            SceneAutomationCurve(
                id: derivedUUID(namespace: id, marker: 3),
                target: .sourceGroup(id),
                parameter: .envelope,
                keyframes: points.sorted { $0.time < $1.time },
                priority: 0
            )
        }
    }

    private struct TimedAction {
        let time: Double
        let order: Int
        let action: APIContentDTO.CueAction
    }

    private static func expandedActions(
        from timeline: APIContentDTO.SceneTimeline
    ) -> [TimedAction] {
        let duration = Double(timeline.duration_hint_seconds ?? 120)
        var result: [TimedAction] = []
        var order = 0
        for cue in timeline.cues {
            let start = cue.at_seconds ?? (cue.progress.map { $0 * duration } ?? 0)
            var times = [start]
            if let repeatEvery = cue.repeat_every_seconds, repeatEvery > 0 {
                times = []
                let end = min(cue.until_seconds ?? duration, duration)
                var time = start
                while time <= end + 0.000_1 {
                    times.append(time)
                    time += repeatEvery
                }
            }
            for time in times {
                for action in cue.actions {
                    result.append(TimedAction(time: time, order: order, action: action))
                    order += 1
                }
            }
        }
        return result.sorted { lhs, rhs in
            if abs(lhs.time - rhs.time) > 0.000_1 { return lhs.time < rhs.time }
            return lhs.order < rhs.order
        }
    }

    private static func polar(from point: CGPoint) -> SpatialPosition {
        SpatialPosition(
            angle: atan2(Double(point.x), Double(-point.y)),
            radius: min(max(Double(hypot(point.x, point.y)), 0), 1)
        )
    }

    private static func layer(for source: SpatialEditorSource) -> AudioLayerKind {
        if source.isVoice { return .voice }
        switch source.theme {
        case .texture: return .trigger
        case .rain: return .environment
        default: return .ambience
        }
    }

    /// Stable IDs for generated start/stop events without adding persisted identity.
    private static func derivedUUID(namespace: UUID, marker: UInt8) -> UUID {
        var bytes = namespace.uuid
        withUnsafeMutableBytes(of: &bytes) { raw in
            raw[15] ^= marker
        }
        return UUID(uuid: bytes)
    }
}
