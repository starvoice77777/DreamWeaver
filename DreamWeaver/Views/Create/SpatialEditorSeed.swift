import CoreGraphics
import Foundation

/// Draft payload for opening the spatial editor blank, from a scene, or from a saved draft.
struct SpatialEditorSeed: Equatable {
    var draftID: UUID?
    var privateSceneID: UUID?
    var sceneName: String
    var soundSources: [SpatialEditorSource]
    var textCues: [SpatialTextCue]
    var durationSeconds: Double?
    var sourceSceneID: UUID?
    var sourceSceneSubtitle: String?

    static let blank = SpatialEditorSeed(
        draftID: nil,
        privateSceneID: nil,
        sceneName: "",
        soundSources: [],
        textCues: [],
        durationSeconds: nil,
        sourceSceneID: nil,
        sourceSceneSubtitle: nil
    )

    static func from(scene: DreamScene) -> SpatialEditorSeed {
        var keptVoice = false
        var sources: [SpatialEditorSource] = []

        for source in scene.soundSources {
            let isVoice = source.layer == .voice
            if isVoice {
                if keptVoice { continue }
                keptVoice = true
            }

            let position = normalizedPoint(from: source.position)
            let matched = matchMaterial(for: source)
            sources.append(
                SpatialEditorSource(
                    materialID: matched?.id,
                    assetID: source.assetId,
                    resourceName: source.resourceName,
                    name: source.name,
                    iconName: source.symbolName,
                    theme: matched?.theme ?? theme(for: source),
                    defaultPosition: position,
                    keyPoints: [
                        SpatialKeyPoint(time: 0, position: position, createdByUser: true)
                    ],
                    isVoice: isVoice || (matched?.isVoice ?? false)
                )
            )
        }

        return SpatialEditorSeed(
            draftID: nil,
            privateSceneID: nil,
            sceneName: scene.name,
            soundSources: sources,
            textCues: [],
            durationSeconds: nil,
            sourceSceneID: scene.id,
            sourceSceneSubtitle: scene.subtitle
        )
    }

    static func from(
        scene: DreamScene,
        timeline: APIContentDTO.SceneTimeline
    ) -> SpatialEditorSeed {
        let importedSources = SceneCompositionMapper.editorSources(
            from: timeline,
            scene: scene
        )
        guard !importedSources.isEmpty else { return from(scene: scene) }
        return SpatialEditorSeed(
            draftID: nil,
            privateSceneID: nil,
            sceneName: scene.name,
            soundSources: importedSources,
            textCues: SceneCompositionMapper.textCues(from: timeline),
            durationSeconds: SceneCompositionMapper.duration(for: timeline),
            sourceSceneID: scene.id,
            sourceSceneSubtitle: scene.subtitle
        )
    }

    static func from(
        scene: DreamScene,
        composition: APIContentDTO.SceneComposition
    ) -> SpatialEditorSeed {
        let sources = SceneCompositionMapper.editorSources(from: composition)
        let duration = composition.duration_seconds
            ?? sources.map(\.audioEndTime).max()
            ?? 120
        return SpatialEditorSeed(
            draftID: nil,
            privateSceneID: nil,
            sceneName: scene.name,
            soundSources: sources,
            textCues: SceneCompositionMapper.textCues(from: composition),
            durationSeconds: duration,
            sourceSceneID: scene.id,
            sourceSceneSubtitle: scene.subtitle
        )
    }

    static func from(draft: CreateSceneDraft) -> SpatialEditorSeed {
        SpatialEditorSeed(
            draftID: draft.id,
            privateSceneID: draft.privateSceneId,
            sceneName: draft.name,
            soundSources: draft.soundSources,
            textCues: draft.textCues,
            durationSeconds: draft.durationSeconds,
            sourceSceneID: draft.sourceSceneId,
            sourceSceneSubtitle: draft.sourceSceneSubtitle
        )
    }

    static func from(
        privateDetail detail: APIContentDTO.PrivateSceneDetail,
        baseScene: DreamScene? = nil
    ) -> SpatialEditorSeed {
        let composition = detail.draft_composition ?? detail.saved_composition
        let timeline = detail.draft_timeline ?? detail.saved_timeline
        if composition == nil, let timeline, let baseScene {
            var imported = from(scene: baseScene, timeline: timeline)
            imported.draftID = nil
            imported.privateSceneID = detail.id
            imported.sceneName = detail.name
            imported.sourceSceneID = detail.source_scene_id
            imported.sourceSceneSubtitle = detail.subtitle
            return imported
        }
        let sources: [SpatialEditorSource]
        if let composition, !composition.tracks.isEmpty {
            sources = SceneCompositionMapper.editorSources(from: composition)
        } else {
            sources = []
        }
        let cues: [SpatialTextCue]
        if let composition {
            cues = SceneCompositionMapper.textCues(from: composition)
        } else {
            cues = []
        }
        return SpatialEditorSeed(
            draftID: nil,
            privateSceneID: detail.id,
            sceneName: detail.name,
            soundSources: sources,
            textCues: cues,
            durationSeconds: composition?.duration_seconds
                ?? timeline.map { SceneCompositionMapper.duration(for: $0) }
                ?? detail.recommended_duration_seconds.map(Double.init),
            sourceSceneID: detail.source_scene_id,
            sourceSceneSubtitle: detail.subtitle
        )
    }

    private static func normalizedPoint(from position: SpatialPosition) -> CGPoint {
        // Match SpatialPosition display convention: 0 = front / screen-up, π/2 = right.
        let radius = min(max(position.radius, 0), 1)
        return CGPoint(
            x: sin(position.angle) * radius,
            y: -cos(position.angle) * radius
        )
    }

    private static func matchMaterial(for source: SoundSource) -> SpatialEditorMaterial? {
        let catalog = SpatialEditorMaterial.catalog
        if source.layer == .voice {
            return catalog.first(where: \.isVoice)
        }

        let symbol = source.symbolName.lowercased()
        let name = source.name.lowercased()

        if let exact = catalog.first(where: { $0.iconName == source.symbolName }) {
            return exact
        }
        if symbol.contains("cloud.rain") || name.contains("雨") {
            return catalog.first { $0.id == "rain" }
        }
        if symbol.contains("wind") || name.contains("风") {
            return catalog.first { $0.id == "wind" }
        }
        if symbol.contains("leaf") || name.contains("竹") || name.contains("虫") {
            return catalog.first { $0.id == (name.contains("虫") ? "insect" : "bamboo") }
        }
        if symbol.contains("piano") || name.contains("钢琴") {
            return catalog.first { $0.id == "piano" }
        }
        if symbol.contains("flame") || name.contains("炉") || name.contains("火") {
            return catalog.first { $0.id == "fire" }
        }
        if symbol.contains("hand") || name.contains("毛巾") {
            return catalog.first { $0.id == "towel" }
        }
        if name.contains("潮") {
            return catalog.first { $0.id == "tide" }
        }
        if symbol.contains("drop") || symbol.contains("water") || name.contains("水") || name.contains("流") {
            return catalog.first { $0.id == "stream" }
        }
        return nil
    }

    private static func theme(for source: SoundSource) -> SpatialSourceTheme {
        switch source.layer {
        case .voice:
            return .narration
        case .ambience:
            return .wind
        case .trigger:
            return .texture
        case .environment:
            return .rain
        }
    }
}
