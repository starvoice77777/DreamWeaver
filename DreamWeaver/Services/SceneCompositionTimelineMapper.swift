import Foundation

/// Turns a Create-editor composition into the same timeline contract used by
/// official scenes, so locally published personal scenes keep clip timing and
/// movement instead of becoming a static list of always-on sources.
enum SceneCompositionTimelineMapper {
    static func timeline(
        from composition: APIContentDTO.SceneComposition,
        sceneId: UUID
    ) -> APIContentDTO.SceneTimeline {
        let duration = max(composition.duration_seconds ?? 120, 1)
        var actionsByTime: [Double: [APIContentDTO.CueAction]] = [:]

        func append(_ action: APIContentDTO.CueAction, at time: Double) {
            let clamped = min(max(time, 0), duration)
            actionsByTime[clamped, default: []].append(action)
        }

        for track in composition.tracks {
            let start = min(max(track.start_seconds, 0), duration)
            let end = min(max(track.end_seconds, start + 0.01), duration)
            let frames = track.keyframes.sorted { $0.t < $1.t }
            if let initial = frames.last(where: { $0.t <= start }) ?? frames.first {
                append(
                    APIContentDTO.CueAction(
                        type: "set_position",
                        track_id: track.id,
                        angle: initial.angle,
                        radius: initial.radius
                    ),
                    at: start
                )
            }
            append(APIContentDTO.CueAction(type: "enable", track_id: track.id), at: start)
            append(
                APIContentDTO.CueAction(
                    type: "set_envelope",
                    track_id: track.id,
                    envelope: 1,
                    fade_ms: 0
                ),
                at: start
            )
            append(
                APIContentDTO.CueAction(
                    type: track.loop == false ? "play_oneshot" : "play",
                    track_id: track.id,
                    resource_key: track.resource_key
                ),
                at: start
            )

            for frame in frames where frame.t > start + 0.001 && frame.t < end - 0.001 {
                append(
                    APIContentDTO.CueAction(
                        type: "set_position",
                        track_id: track.id,
                        angle: frame.angle,
                        radius: frame.radius
                    ),
                    at: frame.t
                )
            }

            if track.loop != false {
                append(
                    APIContentDTO.CueAction(
                        type: "fade_out",
                        track_id: track.id,
                        fade_ms: 300
                    ),
                    at: max(end - 0.3, start)
                )
                append(APIContentDTO.CueAction(type: "pause", track_id: track.id), at: end)
            }
            append(APIContentDTO.CueAction(type: "disable", track_id: track.id), at: end)
        }

        let cues = actionsByTime.keys.sorted().map { time in
            APIContentDTO.Cue(
                id: UUID(),
                at_seconds: time,
                progress: nil,
                repeat_every_seconds: nil,
                until_seconds: nil,
                actions: actionsByTime[time] ?? []
            )
        }
        return APIContentDTO.SceneTimeline(
            scene_id: sceneId,
            version: max(composition.version, 1),
            automation_mode: "personal_composition",
            duration_hint_seconds: Int(ceil(duration)),
            override_policy: "per_source_manual_exit",
            manual_override_track_ids: [],
            phrases: [],
            cues: cues
        )
    }
}
