import Foundation

/// Review assets are available to the manual editor only in Debug builds.
enum HandoffAudioCatalog {
    struct Entry: Decodable {
        let id: String
        let name: String
        let resourceKey: String
        let durationSeconds: Double
        let libraryCategory: String
        let sceneResourceKeys: [String]

        var materialID: String { "handoff:\(id)" }
        var crossfadeMilliseconds: Int {
            sceneResourceKeys.compactMap { HandoffAudioCatalog.loopCrossfades[$0] }.max() ?? 0
        }
        var isLooping: Bool { crossfadeMilliseconds > 0 }
        /// Default for manual authoring; official preset tracks define their own roles.
        var layer: AudioLayerKind {
            if libraryCategory.hasPrefix("01_") { return .environment }
            return libraryCategory.hasPrefix("03_") ? .trigger : .ambience
        }
    }

    private struct Payload: Decodable {
        let version: Int
        let releaseReady: Bool
        let usage: String
        let entries: [Entry]
    }

    // Only loops explicitly declared in the v1.2 scene tracks are enabled.
    // Unspecified source-library files play once, even if their names suggest a loop.
    private static let loopCrossfades = [
        "room_earcare_quiet_01": 500, "room_quiet_01": 500, "fire_soft_01": 1000,
        "ocean_bed_01": 1200, "sea_wind_01": 500, "shore_water_01": 750,
        "boat_water_lap_01": 750, "room_study_quiet_01": 500, "air_winter_far_01": 500,
        "paper_texture_01": 500, "rain_soft": 1000, "rain_parasol": 1200,
        "rain_bamboo_leaf": 800
    ]

    static let entries: [Entry] = {
        #if DEBUG
        for directory in ["Audio", "Resources/Audio", nil] as [String?] {
            guard let url = Bundle.main.url(
                forResource: "handoff_audio_catalog", withExtension: "json", subdirectory: directory
            ) else { continue }
            do {
                let payload = try JSONDecoder().decode(Payload.self, from: Data(contentsOf: url))
                guard payload.version == 1, !payload.releaseReady,
                      payload.usage == "debug_review_only",
                      Set(payload.entries.map(\.id)).count == payload.entries.count,
                      payload.entries.allSatisfy({
                          $0.durationSeconds.isFinite && $0.durationSeconds >= 1
                              && LocalPlaybackService.url(forResource: $0.resourceKey) != nil
                      }) else {
                    assertionFailure("Invalid handoff review catalog or missing audio")
                    return []
                }
                return payload.entries
            } catch {
                assertionFailure("Cannot decode handoff review catalog: \(error)")
                return []
            }
        }
        assertionFailure("Missing handoff review catalog in Debug bundle")
        #endif
        return []
    }()

    static func entry(for materialID: String?) -> Entry? {
        entries.first { $0.materialID == materialID }
    }
}
