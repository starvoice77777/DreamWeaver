import Foundation

/// Versioned local persistence for demo state. Schema bumps enable future migrations.
final class DemoPersistenceStore {
    static let shared = DemoPersistenceStore()

    private let defaults = UserDefaults.standard
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private enum Key {
        static let schema = "dw.demo.v1.schema"
        static let scenesOverlay = "dw.demo.v1.scenesOverlay"
        static let assets = "dw.demo.v1.assets"
        static let usage = "dw.demo.v1.usage"
        static let personalMix = "dw.demo.v1.personalMix"
        static let favorites = "dw.demo.v1.favoriteSceneIds"
        static let createdScenes = "dw.demo.v1.createdScenes"
        static let createdCompositions = "dw.demo.v1.createdCompositions"
    }

    struct ScenesOverlay: Codable {
        var listenCounts: [String: Int]
        var favoriteIds: [UUID]
    }

    struct PersonalMixStore: Codable {
        var byScene: [String: [SoundSource]]
    }

    var schemaVersion: Int {
        get { defaults.integer(forKey: Key.schema) }
        set { defaults.set(newValue, forKey: Key.schema) }
    }

    func migrateIfNeeded() {
        if schemaVersion == 0 {
            schemaVersion = DemoIDs.schemaVersion
        }
        // Future: migrate v1 → v2 here without wiping user data when possible.
    }

    func saveScenesOverlay(_ overlay: ScenesOverlay) throws {
        try save(overlay, key: Key.scenesOverlay)
    }

    func loadScenesOverlay() -> ScenesOverlay? {
        load(Key.scenesOverlay)
    }

    func saveAssets(_ assets: [SoundAsset]) throws {
        try save(assets, key: Key.assets)
    }

    func loadAssets() -> [SoundAsset]? {
        load(Key.assets)
    }

    func saveUsage(_ record: UsageRecord) throws {
        try save(record, key: Key.usage)
    }

    func loadUsage() -> UsageRecord? {
        load(Key.usage)
    }

    func savePersonalMix(_ store: PersonalMixStore) throws {
        try save(store, key: Key.personalMix)
    }

    func loadPersonalMix() -> PersonalMixStore? {
        load(Key.personalMix)
    }

    func saveCreatedScenes(_ scenes: [DreamScene]) throws {
        try save(scenes, key: Key.createdScenes)
    }

    func loadCreatedScenes() -> [DreamScene] {
        load(Key.createdScenes) ?? []
    }

    func saveCreatedComposition(
        _ composition: APIContentDTO.SceneComposition?,
        sceneId: UUID
    ) throws {
        var byScene: [String: APIContentDTO.SceneComposition] =
            load(Key.createdCompositions) ?? [:]
        byScene[sceneId.uuidString] = composition
        try save(byScene, key: Key.createdCompositions)
    }

    func loadCreatedComposition(sceneId: UUID) -> APIContentDTO.SceneComposition? {
        let byScene: [String: APIContentDTO.SceneComposition] =
            load(Key.createdCompositions) ?? [:]
        return byScene[sceneId.uuidString]
    }

    func resetAllDemoKeys() {
        [
            Key.scenesOverlay,
            Key.assets,
            Key.usage,
            Key.personalMix,
            Key.favorites,
            Key.createdScenes,
            Key.createdCompositions
        ].forEach {
            defaults.removeObject(forKey: $0)
        }
        schemaVersion = DemoIDs.schemaVersion
    }

    private func save<T: Encodable>(_ value: T, key: String) throws {
        do {
            let data = try encoder.encode(value)
            defaults.set(data, forKey: key)
        } catch {
            throw ServiceError.persistenceFailed(error.localizedDescription)
        }
    }

    private func load<T: Decodable>(_ key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }
}
