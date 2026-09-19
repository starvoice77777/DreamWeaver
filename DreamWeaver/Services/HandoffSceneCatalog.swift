import Foundation

/// Review presets replace local demo data only when their Debug resources are present.
enum HandoffSceneCatalog {
    static let earSceneID = UUID(uuidString: "A1111111-1111-4111-8111-111111111113")!

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
        return [
            ("handoff_fireplace_v4", DemoIDs.fireplaceScene),
            ("handoff_mist_v4", DemoIDs.mistTideScene),
            ("handoff_ear_v4", earSceneID)
        ].compactMap { name, sceneID in load(name, sceneID: sceneID) }
        #else
        return []
        #endif
    }()

    private static func load(_ name: String, sceneID: UUID) -> Preset? {
        do {
            guard let url = Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "Mock")
                ?? Bundle.main.url(forResource: name, withExtension: "json") else {
                assertionFailure("Missing review preset: \(name)")
                return nil
            }
            let preset = try JSONDecoder().decode(Preset.self, from: Data(contentsOf: url))
            guard !preset.releaseReady, preset.usage == "debug_review_only",
                  preset.sceneID == sceneID,
                  preset.timeline.scene_id == preset.sceneID,
                  !preset.sources.isEmpty,
                  Set(preset.sources.map(\.id)).count == preset.sources.count,
                  preset.sources.allSatisfy({ source in
                      guard let key = source.resourceName else { return false }
                      return LocalPlaybackService.url(forResource: key) != nil
                  }) else {
                assertionFailure("Invalid review preset: \(name)")
                return nil
            }
            return preset
        } catch {
            assertionFailure("Cannot decode review preset \(name): \(error)")
        }
        return nil
    }

    static func replacing(_ scenes: [DreamScene]) -> [DreamScene] {
        let replaced = scenes.map { original in
            guard let preset = presets.first(where: { $0.sceneID == original.id }) else { return original }
            var scene = original
            scene.name = preset.name
            scene.subtitle = preset.subtitle
            scene.description = preset.subtitle
            scene.tags = preset.tags
            scene.soundSources = preset.sources
            scene.isDemoPlayable = true
            scene.audioManifest = audioManifest(for: preset)
            return scene
        }
        let existingIDs = Set(replaced.map(\.id))
        let additions = presets.compactMap { preset -> DreamScene? in
            guard !existingIDs.contains(preset.sceneID), preset.sceneID == earSceneID else { return nil }
            return DreamScene(
                id: preset.sceneID,
                name: preset.name,
                subtitle: preset.subtitle,
                description: preset.subtitle,
                category: .whisper,
                tags: preset.tags,
                palette: ScenePalette(
                    top: 0x15131B,
                    mid: 0x282331,
                    bottom: 0x0B0A10,
                    accent: 0xB79BCB
                ),
                soundSources: preset.sources,
                isFavorite: false,
                isFrequentlyUsed: false,
                listenCount: 0,
                mockListenerCount: 0,
                visualStyle: .emotionalFluid,
                isDemoPlayable: true,
                audioManifest: audioManifest(for: preset)
            )
        }
        return replaced + additions
    }

    static func timeline(for sceneID: UUID) -> APIContentDTO.SceneTimeline? {
        presets.first { $0.sceneID == sceneID }?.timeline
    }

    private static func audioManifest(for preset: Preset) -> SceneAudioManifest {
        SceneAudioManifest(tracks: preset.sources.compactMap { source in
            guard let key = source.resourceName else { return nil }
            return AudioTrackRef(
                id: source.id, name: source.name, symbolName: source.symbolName,
                resourceName: key, layer: source.layer,
                loops: preset.loopCrossfades[key] != nil,
                initialEnvelope: source.initialEnvelope, defaultPosition: source.position
            )
        }, voicePhraseResourceName: nil)
    }
}
