import Foundation

/// Local stub matching server hair-care / rain-eaves fixtures (Stage 6).
/// Used by `LocalContentService.fetchTimeline` and as playback fallback when no timeline is passed.
enum LocalTimelineFixture {
    private static let phraseMomId = UUID(uuidString: "F6666666-6666-4666-8666-666666666601")!
    private static let cueFirstId = UUID(uuidString: "F6666666-6666-4666-8666-666666666611")!
    private static let cueRepeatId = UUID(uuidString: "F6666666-6666-4666-8666-666666666612")!
    private static let cueRainSettleId = UUID(uuidString: "F6666666-6666-4666-8666-666666666621")!
    private static let cueWindSoftenId = UUID(uuidString: "F6666666-6666-4666-8666-666666666622")!
    private static let rainTrackId = UUID(uuidString: "E5555555-5555-4555-8555-555555555501")!
    private static let windTrackId = UUID(uuidString: "E5555555-5555-4555-8555-555555555502")!

    static func timeline(for sceneId: UUID) -> APIContentDTO.SceneTimeline {
        if sceneId == DemoIDs.hairCareScene {
            return hairCareTimeline(sceneId: sceneId)
        }
        if sceneId == DemoIDs.rainEavesScene {
            return rainEavesTimeline(sceneId: sceneId)
        }
        return emptyTimeline(sceneId: sceneId)
    }

    private static func emptyTimeline(sceneId: UUID) -> APIContentDTO.SceneTimeline {
        APIContentDTO.SceneTimeline(
            scene_id: sceneId,
            version: 1,
            automation_mode: "official_auto",
            duration_hint_seconds: 2700,
            override_policy: "per_source_manual_exit",
            manual_override_track_ids: [],
            phrases: [],
            cues: []
        )
    }

    private static func hairCareTimeline(sceneId: UUID) -> APIContentDTO.SceneTimeline {
        let duration = 2700
        let phrase = APIContentDTO.Phrase(
            id: phraseMomId,
            text: "睡吧，我在。",
            review_status: "approved",
            voice_binding: APIContentDTO.VoiceBinding(
                kind: "official_resource",
                resource_key: "voice_phrase_mom",
                asset_id: nil,
                track_id: DemoIDs.sourceVoice,
                track_layer: "voice"
            )
        )
        let first = APIContentDTO.Cue(
            id: cueFirstId,
            at_seconds: 6,
            progress: nil,
            repeat_every_seconds: nil,
            until_seconds: nil,
            actions: [
                APIContentDTO.CueAction(
                    type: "play_phrase",
                    phrase_id: phraseMomId,
                    track_id: DemoIDs.sourceVoice,
                    volume: nil,
                    fade_ms: nil,
                    angle: nil,
                    radius: nil,
                    resource_key: nil
                )
            ]
        )
        let repeatCue = APIContentDTO.Cue(
            id: cueRepeatId,
            at_seconds: 34,
            progress: nil,
            repeat_every_seconds: 28,
            until_seconds: Double(duration),
            actions: [
                APIContentDTO.CueAction(
                    type: "play_phrase",
                    phrase_id: phraseMomId,
                    track_id: DemoIDs.sourceVoice,
                    volume: nil,
                    fade_ms: nil,
                    angle: nil,
                    radius: nil,
                    resource_key: nil
                )
            ]
        )
        return APIContentDTO.SceneTimeline(
            scene_id: sceneId,
            version: 1,
            automation_mode: "official_auto",
            duration_hint_seconds: duration,
            override_policy: "per_source_manual_exit",
            manual_override_track_ids: [],
            phrases: [phrase],
            cues: [first, repeatCue]
        )
    }

    private static func rainEavesTimeline(sceneId: UUID) -> APIContentDTO.SceneTimeline {
        APIContentDTO.SceneTimeline(
            scene_id: sceneId,
            version: 1,
            automation_mode: "official_auto",
            duration_hint_seconds: 2700,
            override_policy: "per_source_manual_exit",
            manual_override_track_ids: [],
            phrases: [],
            cues: [
                APIContentDTO.Cue(
                    id: cueRainSettleId,
                    at_seconds: 90,
                    progress: nil,
                    repeat_every_seconds: nil,
                    until_seconds: nil,
                    actions: [
                        APIContentDTO.CueAction(
                            type: "set_volume",
                            phrase_id: nil,
                            track_id: rainTrackId,
                            volume: 0.65,
                            fade_ms: 5000,
                            angle: nil,
                            radius: nil,
                            resource_key: nil
                        )
                    ]
                ),
                APIContentDTO.Cue(
                    id: cueWindSoftenId,
                    at_seconds: 240,
                    progress: nil,
                    repeat_every_seconds: nil,
                    until_seconds: nil,
                    actions: [
                        APIContentDTO.CueAction(
                            type: "set_volume",
                            phrase_id: nil,
                            track_id: windTrackId,
                            volume: 0.22,
                            fade_ms: 6000,
                            angle: nil,
                            radius: nil,
                            resource_key: nil
                        )
                    ]
                )
            ]
        )
    }
}
