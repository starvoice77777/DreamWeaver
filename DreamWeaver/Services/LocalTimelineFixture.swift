import Foundation

/// Local / remote-aligned timeline fixtures (Stage 6).
enum LocalTimelineFixture {
    static func timeline(for sceneId: UUID) -> APIContentDTO.SceneTimeline {
        if sceneId == DemoIDs.hairCareScene, let scripted = loadHairCareV4() {
            return scripted
        }
        if sceneId == DemoIDs.rainEavesScene {
            return rainEavesTimeline(sceneId: sceneId)
        }
        return emptyTimeline(sceneId: sceneId)
    }

    private static func loadHairCareV4() -> APIContentDTO.SceneTimeline? {
        guard let url = Bundle.main.url(
            forResource: "hair_care_timeline_v4",
            withExtension: "json",
            subdirectory: "Mock"
        ) ?? Bundle.main.url(forResource: "hair_care_timeline_v4", withExtension: "json") else {
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(APIContentDTO.SceneTimeline.self, from: data)
        } catch {
            return nil
        }
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

    private static let cueRainSettleId = UUID(uuidString: "F6666666-6666-4666-8666-666666666621")!
    private static let cueWindSoftenId = UUID(uuidString: "F6666666-6666-4666-8666-666666666622")!

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
                            track_id: DemoIDs.sourceRain,
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
                            track_id: DemoIDs.sourceWind,
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
