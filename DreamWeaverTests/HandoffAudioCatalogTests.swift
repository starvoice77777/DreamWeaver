import Foundation
import Testing
@testable import DreamWeaver

@MainActor
@Suite("Handoff audio in the manual editor")
struct HandoffAudioCatalogTests {
    private func material(_ id: String) throws -> SpatialEditorMaterial {
        try #require(SpatialEditorMaterial.catalog.first { $0.id == "handoff:\(id)" })
    }

    @Test("Debug catalog exposes all 57 playable resources without fabricated backend IDs")
    func catalogResources() {
        #if DEBUG
        let materials = SpatialEditorMaterial.catalog.filter { $0.id.hasPrefix("handoff:") }
        #expect(materials.count == 57)
        for entry in HandoffAudioCatalog.entries {
            #expect(LocalPlaybackService.url(forResource: entry.resourceKey) != nil)
            #expect(materials.first { $0.id == entry.materialID }?.audioDuration == entry.durationSeconds)
        }
        #expect(materials.allSatisfy { $0.assetID == nil && !$0.isVoice })
        #else
        #expect(HandoffAudioCatalog.entries.isEmpty)
        #expect(!SpatialEditorMaterial.catalog.contains { $0.id.hasPrefix("handoff:") })
        #endif
    }

    #if DEBUG
    @Test("One-shots keep real duration and survive composition round trips",
          arguments: ["page_turn_slow_a", "ear_cotton_swab_long", "wind_gust_far", "brown_noise_soft"])
    func oneShots(id: String) throws {
        let selected = try material(id)
        let model = SpatialTimelineViewModel()
        defer { model.stopForDismissal() }
        model.addMaterial(selected)
        let clip = try #require(model.audioClips.first)
        #expect(!clip.isLooping)
        #expect(clip.duration == selected.audioDuration)
        #expect(clip.crossfadeMilliseconds == 0)
        #expect(model.duration >= clip.endTime)
        let document = model.makeCompositionDocument()
        let restored = try #require(SceneCompositionMapper.editorSources(from: document).first)
        #expect(restored.materialID == selected.id)
        #expect(restored.resourceName == selected.resourceName)
        #expect(restored.audioDuration == clip.duration)
        #expect(restored.isLooping == false)
        let roundTrip = SceneCompositionMapper.composition(from: [restored], duration: model.duration)
        #expect(roundTrip.source_groups?.first?.layer == document.source_groups?.first?.layer)
        var scene = try #require(MockDataService.makeScenes().first)
        scene.soundSources = model.makeSoundSources(baseScene: nil)
        let fallback = try #require(SpatialEditorSeed.from(scene: scene).soundSources.first)
        #expect(fallback.materialID == selected.id)
        #expect(fallback.audioDuration == selected.audioDuration)
        #expect(fallback.isLooping == false)
    }

    @Test("Shared waveform icons do not merge different material names when saving")
    func distinctSources() throws {
        let model = SpatialTimelineViewModel()
        defer { model.stopForDismissal() }
        model.addMaterial(try material("page_turn_slow_a"))
        var scene = try #require(MockDataService.makeScenes().first)
        scene.soundSources = model.makeSoundSources(baseScene: nil)
        model.addMaterial(try material("wood_crackle_01"))
        let saved = model.makeSoundSources(baseScene: scene)
        #expect(Set(saved.map(\.name)).count == 2)
        #expect(Set(saved.compactMap(\.resourceName)).count == 2)
    }

    @Test("Declared loops get crossfades and repeated additions share one source group")
    func loopInsertion() throws {
        let selected = try material("room_study_quiet_loop")
        let model = SpatialTimelineViewModel()
        defer { model.stopForDismissal() }
        model.addMaterial(selected)
        model.addMaterial(selected)
        #expect(model.sourceGroups.count == 1)
        #expect(model.audioClips.count == 2)
        #expect(model.audioClips.allSatisfy {
            $0.isLooping && $0.duration == 30 && $0.crossfadeMilliseconds == 500
        })
        #expect(model.audioClips[1].startTime == model.audioClips[0].endTime)
        #expect(model.makeCompositionDocument().source_groups?.first?.layer == "environment")
    }

    @Test("Legacy rain insertion keeps its existing 30-second loop")
    func legacyRain() throws {
        let rain = try #require(SpatialEditorMaterial.catalog.first { $0.id == "rain" })
        let model = SpatialTimelineViewModel()
        defer { model.stopForDismissal() }
        model.addMaterial(rain)
        let clip = try #require(model.audioClips.first)
        #expect(clip.isLooping && clip.duration == 30 && clip.crossfadeMilliseconds == 1000)
    }
    #endif
}
