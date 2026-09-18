import Foundation

/// Review presets replace local demo data only when their Debug resources are present.
enum HandoffSceneCatalog {
    private struct Preset: Decodable {
        let sceneID: UUID
        let name: String
        let subtitle: String
        let tags: [String]
        let releaseReady: Bool
        let usage: String
        let sources: [SoundSource]
        let loopCrossfades: [String: Int]
        let timeline: APIContentDTO.SceneTimeline
    }

    private static let presets: [Preset] = {
        #if DEBUG
        do {
            guard let url = Bundle.main.url(forResource: "handoff_fireplace_v4", withExtension: "json", subdirectory: "Mock")
                ?? Bundle.main.url(forResource: "handoff_fireplace_v4", withExtension: "json") else {
                assertionFailure("Missing fireplace review preset")
                return []
            }
            let preset = try JSONDecoder().decode(Preset.self, from: Data(contentsOf: url))
            guard !preset.releaseReady, preset.usage == "debug_review_only",
                  preset.sceneID == DemoIDs.fireplaceScene,
                  preset.timeline.scene_id == preset.sceneID,
                  !preset.sources.isEmpty,
                  Set(preset.sources.map(\.id)).count == preset.sources.count,
                  preset.sources.allSatisfy({ source in
                      guard let key = source.resourceName else { return false }
                      return LocalPlaybackService.url(forResource: key) != nil
                  }) else {
                assertionFailure("Invalid fireplace review preset")
                return []
            }
            return [preset]
        } catch {
            assertionFailure("Cannot decode fireplace review preset: \(error)")
        }
        #endif
        return []
    }()

    static func replacing(_ scenes: [DreamScene]) -> [DreamScene] {
        scenes.map { original in
            guard let preset = presets.first(where: { $0.sceneID == original.id }) else { return original }
            var scene = original
            scene.name = preset.name
            scene.subtitle = preset.subtitle
            scene.description = preset.subtitle
            scene.tags = preset.tags
            scene.soundSources = preset.sources
            scene.isDemoPlayable = true
            scene.audioManifest = SceneAudioManifest(tracks: preset.sources.compactMap { source in
                guard let key = source.resourceName else { return nil }
                return AudioTrackRef(
                    id: source.id, name: source.name, symbolName: source.symbolName,
                    resourceName: key, layer: source.layer,
                    loops: preset.loopCrossfades[key] != nil,
                    initialEnvelope: source.initialEnvelope, defaultPosition: source.position
                )
            }, voicePhraseResourceName: nil)
            return scene
        }
    }

    static func timeline(for sceneID: UUID) -> APIContentDTO.SceneTimeline? {
        presets.first { $0.sceneID == sceneID }?.timeline
    }
}
