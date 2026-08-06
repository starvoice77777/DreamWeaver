import Foundation

@MainActor
final class LocalContentService: ContentService {
    private let store = DemoPersistenceStore.shared

    func loadBootstrap() async throws -> BootstrapPayload {
        MockDataService.makeBootstrap()
    }

    func fetchScenes() async throws -> [DreamScene] {
        var scenes = MockDataService.makeScenes()
        if let overlay = store.loadScenesOverlay() {
            scenes = scenes.map { scene in
                var updated = scene
                if let count = overlay.listenCounts[scene.id.uuidString] {
                    updated.listenCount = count
                }
                updated.isFavorite = overlay.favoriteIds.contains(scene.id)
                return updated
            }
            scenes = MockDataService.markTopFrequentScenes(scenes)
        }
        return scenes
    }

    func fetchScene(id: UUID) async throws -> DreamScene {
        let scenes = try await fetchScenes()
        guard let scene = scenes.first(where: { $0.id == id }) else {
            throw ServiceError.notFound(id.uuidString)
        }
        return scene
    }

    func fetchMixPresets(sceneStyle: SceneVisualStyle?) async throws -> [MixPreset] {
        let all = MockDataService.makeMixPresets()
        guard let style = sceneStyle else { return all }
        switch style {
        case .hairCare:
            return all.filter { $0.id == DemoIDs.presetHairCare || $0.authorType == .official }
        case .rainEaves:
            return all.filter { $0.id == DemoIDs.presetRainFine || $0.id == DemoIDs.presetBreathOnly || $0.authorType == .community }
        default:
            return all
        }
    }

    func fetchTimeline(sceneId: UUID) async throws -> APIContentDTO.SceneTimeline {
        LocalTimelineFixture.timeline(for: sceneId)
    }

    func randomGreeting() -> String {
        MockDataService.greetings.randomElement() ?? MockDataService.greetings[0]
    }

    func persistSceneOverlay(scenes: [DreamScene]) throws {
        let overlay = DemoPersistenceStore.ScenesOverlay(
            listenCounts: Dictionary(uniqueKeysWithValues: scenes.map { ($0.id.uuidString, $0.listenCount) }),
            favoriteIds: scenes.filter(\.isFavorite).map(\.id)
        )
        try store.saveScenesOverlay(overlay)
    }
}

@MainActor
final class LocalUserLibraryService: UserLibraryService {
    private let store = DemoPersistenceStore.shared
    private var cache: [SoundAsset]

    init() {
        store.migrateIfNeeded()
        cache = store.loadAssets() ?? MockDataService.makeSoundAssets()
    }

    func fetchAssets() async throws -> [SoundAsset] {
        cache
    }

    func upsert(_ asset: SoundAsset) async throws {
        if let idx = cache.firstIndex(where: { $0.id == asset.id }) {
            cache[idx] = asset
        } else {
            cache.insert(asset, at: 0)
        }
        try store.saveAssets(cache)
    }

    func delete(id: UUID) async throws {
        cache.removeAll { $0.id == id }
        try store.saveAssets(cache)
    }

    func deleteImpact(id: UUID) async throws -> LibraryDeleteImpact {
        LibraryDeleteImpact(assetId: id, totalReferences: 0, affectedScenes: [])
    }

    func toggleFavorite(id: UUID) async throws -> SoundAsset {
        guard let idx = cache.firstIndex(where: { $0.id == id }) else {
            throw ServiceError.notFound(id.uuidString)
        }
        cache[idx].isFavorite.toggle()
        try store.saveAssets(cache)
        return cache[idx]
    }

    func rename(id: UUID, name: String) async throws {
        guard let idx = cache.firstIndex(where: { $0.id == id }) else {
            throw ServiceError.notFound(id.uuidString)
        }
        cache[idx].name = name
        try store.saveAssets(cache)
    }

    func resetToFixture() async throws {
        cache = MockDataService.makeSoundAssets()
        try store.saveAssets(cache)
    }
}

@MainActor
final class LocalAnalyticsService: AnalyticsService {
    private let store = DemoPersistenceStore.shared
    private var record: UsageRecord

    init() {
        record = store.loadUsage() ?? MockDataService.makeUsageRecord()
    }

    func summary() async throws -> UsageRecord {
        record
    }

    func record(_ event: AnalyticsEvent) async throws {
        switch event {
        case .sceneListen:
            record.lastUsedAt = Date()
            record.weekMinutes += 1
            record.totalMinutes += 1
            if !record.sleepTrend.isEmpty {
                record.sleepTrend[record.sleepTrend.count - 1] += 1
            }
        case .sessionEnded(_, let durationSeconds):
            let minutes = max(durationSeconds / 60, 1)
            record.totalMinutes += minutes
            record.weekMinutes += minutes
            record.lastUsedAt = Date()
            if !record.sleepTrend.isEmpty {
                record.sleepTrend[record.sleepTrend.count - 1] += minutes
            }
        case .mixEdited:
            record.lastUsedAt = Date()
        }
        try store.saveUsage(record)
    }

    func resetDemoStats() async throws {
        record = MockDataService.makeUsageRecord()
        try store.saveUsage(record)
    }
}
