import Foundation

struct DreamScene: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var subtitle: String
    var description: String
    var category: SceneCategory
    var tags: [String]
    var palette: ScenePalette
    var soundSources: [SoundSource]
    var isFavorite: Bool
    var isFrequentlyUsed: Bool
    /// Demo listen sessions used to derive「常用」.
    var listenCount: Int
    /// Demo-only mock listener count.
    var mockListenerCount: Int
    var visualStyle: SceneVisualStyle
    /// When true, scene has a local multi-track audio manifest for credible playback.
    var isDemoPlayable: Bool
    var audioManifest: SceneAudioManifest?

    var shortTags: String {
        tags.prefix(2).joined(separator: " · ")
    }

    enum CodingKeys: String, CodingKey {
        case id, name, subtitle, description, category, tags, palette
        case soundSources, isFavorite, isFrequentlyUsed, listenCount
        case mockListenerCount, visualStyle, isDemoPlayable, audioManifest
    }

    init(
        id: UUID,
        name: String,
        subtitle: String,
        description: String,
        category: SceneCategory,
        tags: [String],
        palette: ScenePalette,
        soundSources: [SoundSource],
        isFavorite: Bool,
        isFrequentlyUsed: Bool,
        listenCount: Int,
        mockListenerCount: Int,
        visualStyle: SceneVisualStyle,
        isDemoPlayable: Bool = false,
        audioManifest: SceneAudioManifest? = nil
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.description = description
        self.category = category
        self.tags = tags
        self.palette = palette
        self.soundSources = soundSources
        self.isFavorite = isFavorite
        self.isFrequentlyUsed = isFrequentlyUsed
        self.listenCount = listenCount
        self.mockListenerCount = mockListenerCount
        self.visualStyle = visualStyle
        self.isDemoPlayable = isDemoPlayable
        self.audioManifest = audioManifest
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        subtitle = try c.decode(String.self, forKey: .subtitle)
        description = try c.decode(String.self, forKey: .description)
        category = try c.decode(SceneCategory.self, forKey: .category)
        tags = try c.decode([String].self, forKey: .tags)
        palette = try c.decode(ScenePalette.self, forKey: .palette)
        soundSources = try c.decode([SoundSource].self, forKey: .soundSources)
        isFavorite = try c.decode(Bool.self, forKey: .isFavorite)
        isFrequentlyUsed = try c.decode(Bool.self, forKey: .isFrequentlyUsed)
        listenCount = try c.decode(Int.self, forKey: .listenCount)
        mockListenerCount = try c.decode(Int.self, forKey: .mockListenerCount)
        visualStyle = try c.decode(SceneVisualStyle.self, forKey: .visualStyle)
        isDemoPlayable = try c.decodeIfPresent(Bool.self, forKey: .isDemoPlayable) ?? false
        audioManifest = try c.decodeIfPresent(SceneAudioManifest.self, forKey: .audioManifest)
    }
}

enum SceneVisualStyle: String, Codable, Hashable, CaseIterable {
    case rainEaves
    case fireflies
    case mistTide
    case valleyStream
    case moonLake
    case starRiver
    case warmLamp
    case snowStudy
    case wheatWind
    case cloudBreath
    case summerInsects
    case fireplaceWhisper
    case hairCare
}
