import CoreGraphics
import Foundation

enum AssistedAISceneBridge {
    static func selectedSources(
        from draft: AssistedCreationDraft
    ) throws -> [AISceneDTO.SelectedSource] {
        try draft.selections.map { selection in
            let profile = try profile(for: selection.material)
            let position = selection.zone.editorPosition
            return AISceneDTO.SelectedSource(
                sourceID: profile.sourceID,
                resourceKey: profile.resourceKey,
                name: selection.material.name,
                description: profile.description,
                layer: profile.layer,
                loop: profile.loop,
                durationSeconds: profile.durationSeconds,
                defaultVolume: profile.defaultVolume,
                angle: atan2(position.x, -position.y),
                radius: min(hypot(position.x, position.y), 1)
            )
        }
    }

    static func editorSeed(
        from draft: AssistedCreationDraft,
        result: AISceneDTO.GenerateResult
    ) throws -> SpatialEditorSeed {
        let sources = SceneCompositionMapper.editorSources(from: result.composition)
        guard !sources.isEmpty else {
            throw ServiceError.decoding("AI 返回的场景没有可编辑声源")
        }
        let generatedName = result.scene.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let sceneName: String
        if let generatedName, !generatedName.isEmpty {
            sceneName = generatedName
        } else {
            sceneName = draft.sceneName
        }
        return SpatialEditorSeed(
            draftID: draft.id,
            privateSceneID: nil,
            sceneName: sceneName,
            soundSources: sources,
            textCues: SceneCompositionMapper.textCues(from: result.composition),
            durationSeconds: result.composition.duration_seconds ?? 120,
            sourceSceneID: nil,
            sourceSceneSubtitle: result.scene.subtitle
        )
    }

    private static func profile(for material: SpatialEditorMaterial) throws -> SourceProfile {
        if let sourceID = material.assetID,
           let resourceKey = material.resourceName,
           let duration = material.audioDuration {
            return SourceProfile(
                sourceID: sourceID,
                resourceKey: resourceKey,
                description: material.name,
                layer: material.isVoice ? .voice : .ambience,
                loop: !material.isVoice,
                durationSeconds: duration,
                defaultVolume: 0.35
            )
        }
        guard let profile = bundledProfiles[material.id] else {
            throw ServiceError.invalidState(
                String(localized: "“\(material.name)”尚未取得后端素材 ID，暂时不能用于 AI 生成")
            )
        }
        return profile
    }

    private struct SourceProfile {
        let sourceID: UUID
        let resourceKey: String
        let description: String
        let layer: AISceneDTO.Layer
        let loop: Bool
        let durationSeconds: Double
        let defaultVolume: Double
    }

    private static let bundledProfiles: [String: SourceProfile] = [
        "rain": SourceProfile(
            sourceID: DemoIDs.sourceRainSoftFar,
            resourceKey: "rain_soft",
            description: "柔和、连续的远雨声",
            layer: .environment,
            loop: true,
            durationSeconds: 11.596,
            defaultVolume: 0.22
        ),
        "wind": SourceProfile(
            sourceID: DemoIDs.sourceWind,
            resourceKey: "wind_gust",
            description: "短促、自然的阵风细节",
            layer: .trigger,
            loop: false,
            durationSeconds: 3.709,
            defaultVolume: 0.20
        ),
        "bamboo": SourceProfile(
            sourceID: DemoIDs.sourceRainBambooLeaf,
            resourceKey: "rain_bamboo_leaf",
            description: "轻柔、连续的竹叶雨声",
            layer: .ambience,
            loop: true,
            durationSeconds: 6.05,
            defaultVolume: 0.27
        ),
        "stream": SourceProfile(
            sourceID: UUID(uuidString: "f6666666-6666-4666-8666-000000010501")!,
            resourceKey: "stream_nature",
            description: "清晰、连续的自然流水声",
            layer: .environment,
            loop: true,
            durationSeconds: 70.775,
            defaultVolume: 0.40
        ),
        "towel": SourceProfile(
            sourceID: DemoIDs.sourceHairTowel,
            resourceKey: "hair_towel",
            description: "近场、短促的毛巾摩擦声",
            layer: .trigger,
            loop: false,
            durationSeconds: 6,
            defaultVolume: 0.43
        ),
    ]
}
