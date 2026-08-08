import Foundation

/// Local / remote-aligned timeline fixtures (Stage 6).
enum LocalTimelineFixture {
    static func timeline(for sceneId: UUID) -> APIContentDTO.SceneTimeline {
        if sceneId == DemoIDs.hairCareScene, let scripted = loadHairCareV11() {
            return scripted
        }
        if sceneId == DemoIDs.rainEavesScene, let scripted = loadRainEavesV9() {
            return scripted
        }
        return emptyTimeline(sceneId: sceneId)
    }

    private static func loadRainEavesV9() -> APIContentDTO.SceneTimeline? {
        guard let url = Bundle.main.url(
            forResource: "rain_eaves_timeline_v9",
            withExtension: "json",
            subdirectory: "Mock"
        ) ?? Bundle.main.url(forResource: "rain_eaves_timeline_v9", withExtension: "json") else {
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(APIContentDTO.SceneTimeline.self, from: data)
        } catch {
            assertionFailure("rain_eaves_timeline_v9 decode failed: \(error)")
            return nil
        }
    }

    private static func loadHairCareV11() -> APIContentDTO.SceneTimeline? {
        guard let url = Bundle.main.url(
            forResource: "hair_care_timeline_v11",
            withExtension: "json",
            subdirectory: "Mock"
        ) ?? Bundle.main.url(forResource: "hair_care_timeline_v11", withExtension: "json") else {
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(APIContentDTO.SceneTimeline.self, from: data)
        } catch {
            assertionFailure("hair_care_timeline_v11 decode failed: \(error)")
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

}
