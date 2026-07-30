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

    var shortTags: String {
        tags.prefix(2).joined(separator: " · ")
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
}
