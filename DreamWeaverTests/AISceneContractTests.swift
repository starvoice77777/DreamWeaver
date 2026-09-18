import Foundation
import Testing
@testable import DreamWeaver

@Suite("AI scene-assist contract")
struct AISceneContractTests {
    private let sourceID = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!

    @Test("Generate request uses backend field names and values")
    func generateRequestEncoding() throws {
        let request = AISceneDTO.GenerateRequest(
            selectedSources: [selectedSource()],
            options: AISceneDTO.Options(
                sceneIntent: "睡前放松",
                durationSeconds: 1_800,
                constraints: ["不要加入人声"]
            )
        )

        let data = try JSONEncoder().encode(request)
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let sources = try #require(object["selected_sources"] as? [[String: Any]])
        let source = try #require(sources.first)
        let options = try #require(object["options"] as? [String: Any])

        #expect(sources.count == 1)
        #expect(UUID(uuidString: source["source_id"] as? String ?? "") == sourceID)
        #expect(source["resource_key"] as? String == "rain_soft")
        #expect(source["layer"] as? String == "environment")
        #expect(source["duration_seconds"] as? Double == 30)
        #expect(source["default_volume"] as? Double == 0.3)
        #expect(options["scene_intent"] as? String == "睡前放松")
        #expect(options["duration_seconds"] as? Double == 1_800)
        #expect(options["language"] as? String == "zh-CN")
        #expect(options["constraints"] as? [String] == ["不要加入人声"])
    }

    @Test("Generate response decodes a version-two composition for the editor")
    func generateResponseDecoding() throws {
        let result = try JSONDecoder().decode(
            AISceneDTO.GenerateResult.self,
            from: Data(Self.generateResponseJSON.utf8)
        )

        #expect(result.scene.name == "檐下听雨")
        #expect(result.composition.schema == "scene_composition_v2")
        #expect(result.composition.version == 2)
        #expect(result.composition.clips?.first?.asset_id == sourceID)
        #expect(result.validationWarnings == ["许可证待人工确认"])

        let editorSources = SceneCompositionMapper.editorSources(from: result.composition)
        let source = try #require(editorSources.first)
        #expect(editorSources.count == 1)
        #expect(source.assetID == sourceID)
        #expect(source.resourceName == "rain_soft")
        #expect(source.audioDuration == 1_800)
        #expect(source.isLooping == true)
    }

    @Test("Adjust request carries the full composition and natural-language instruction")
    func adjustRequestEncoding() throws {
        let generated = try JSONDecoder().decode(
            AISceneDTO.GenerateResult.self,
            from: Data(Self.generateResponseJSON.utf8)
        )
        let request = AISceneDTO.AdjustRequest(
            selectedSources: [selectedSource()],
            scene: AISceneDTO.SceneMetadata(
                name: generated.scene.name,
                subtitle: generated.scene.subtitle,
                composition: generated.composition
            ),
            instruction: "把雨声降低一些"
        )

        let data = try JSONEncoder().encode(request)
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let scene = try #require(object["scene"] as? [String: Any])
        let composition = try #require(scene["composition"] as? [String: Any])

        #expect(object["instruction"] as? String == "把雨声降低一些")
        #expect(composition["schema"] as? String == "scene_composition_v2")
        #expect(composition["version"] as? Int == 2)
        #expect(composition["tracks"] == nil)
    }

    private func selectedSource() -> AISceneDTO.SelectedSource {
        AISceneDTO.SelectedSource(
            sourceID: sourceID,
            resourceKey: "rain_soft",
            name: "轻雨",
            description: "柔和、连续的雨声",
            layer: .environment,
            loop: true,
            durationSeconds: 30,
            defaultVolume: 0.3,
            angle: 0,
            radius: 0.8
        )
    }

    private static let generateResponseJSON = #"""
    {
      "outline": {
        "name": "檐下听雨",
        "subtitle": "安静入睡"
      },
      "arrangement": {
        "tracks": []
      },
      "scene": {
        "name": "檐下听雨",
        "subtitle": "安静入睡"
      },
      "composition": {
        "schema": "scene_composition_v2",
        "version": 2,
        "duration_seconds": 1800,
        "source_groups": [
          {
            "id": "11111111-1111-4111-8111-111111111111",
            "name": "轻雨",
            "symbol_name": null,
            "layer": "environment",
            "display_policy": "while_active",
            "position_keyframes": [
              {"t": 0, "angle": 0, "radius": 0.8, "interpolation": "smoothstep"}
            ]
          }
        ],
        "clips": [
          {
            "id": "22222222-2222-4222-8222-222222222222",
            "source_group_id": "11111111-1111-4111-8111-111111111111",
            "asset_id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
            "resource_key": "rain_soft",
            "start_seconds": 0,
            "end_seconds": 1800,
            "source_offset_seconds": 0,
            "playback_mode": "loop",
            "crossfade_ms": 500,
            "fade_in_ms": 500,
            "fade_out_ms": 500
          }
        ]
      },
      "validation_warnings": ["许可证待人工确认"]
    }
    """#
}
