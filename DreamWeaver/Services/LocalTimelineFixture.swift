import Foundation

/// Local / remote-aligned timeline fixtures (Stage 6).
enum LocalTimelineFixture {
    static func timeline(for sceneId: UUID) -> APIContentDTO.SceneTimeline {
        if sceneId == DemoIDs.hairCareScene, let scripted = loadHairCareV4() {
            return scripted
        }
        if sceneId == DemoIDs.rainEavesScene, let scripted = loadRainEavesV5() {
            return scripted
        }
        return emptyTimeline(sceneId: sceneId)
    }

    private static func loadRainEavesV5() -> APIContentDTO.SceneTimeline? {
        guard let url = Bundle.main.url(
            forResource: "rain_eaves_timeline_v5",
            withExtension: "json",
            subdirectory: "Mock"
        ) ?? Bundle.main.url(forResource: "rain_eaves_timeline_v5", withExtension: "json") else {
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(APIContentDTO.SceneTimeline.self, from: data)
        } catch {
            return nil
        }
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

}
