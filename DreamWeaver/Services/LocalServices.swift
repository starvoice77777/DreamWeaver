import Foundation

@MainActor
final class LocalContentService: ContentService {
    private let store = DemoPersistenceStore.shared

    func loadBootstrap() async throws -> BootstrapPayload {
        var payload = MockDataService.makeBootstrap()
        if let last = UserDefaults.standard.string(forKey: "dw.lastSceneId"),
           let id = UUID(uuidString: last) {
            payload.recommendedSceneId = id
        }
        return payload
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
        case .seedCreated, .mixEdited:
            record.lastUsedAt = Date()
        }
        try store.saveUsage(record)
    }

    func resetDemoStats() async throws {
        record = MockDataService.makeUsageRecord()
        try store.saveUsage(record)
    }
}

@MainActor
final class LocalSeedPipelineService: SeedPipelineService {
    private var jobs: [UUID: SeedJob] = [:]
    private var authorized = false

    func analyze(durationSeconds: Int) async throws -> SeedQualityReport {
        try await Task.sleep(nanoseconds: 800_000_000)
        return MockDataService.makeSeedQuality(durationSeconds: durationSeconds)
    }

    func authorize(confirmed: Bool) async throws {
        guard confirmed else { throw ServiceError.unauthorized }
        authorized = true
    }

    func startProcess(durationSeconds: Int) async throws -> SeedJob {
        guard authorized else { throw ServiceError.unauthorized }
        let job = SeedJob(
            id: UUID(),
            status: .processing,
            progress: 0,
            message: "正在整理声音片段",
            resultAsset: nil,
            previewResourceName: "voice_phrase_mom"
        )
        jobs[job.id] = job
        return job
    }

    func pollJob(id: UUID) async throws -> SeedJob {
        guard var job = jobs[id] else { throw ServiceError.notFound(id.uuidString) }
        if job.status == .completed { return job }

        let messages = ["正在整理声音片段", "正在保留声音特点", "正在准备试听版本"]
        let next = min(job.progress + 0.08, 1.0)
        job.progress = next
        job.message = messages[min(Int(next * 3), messages.count - 1)]
        if next >= 1 {
            job.status = .completed
            job.message = "已准备好试听版本"
        } else {
            job.status = .processing
        }
        jobs[id] = job
        try await Task.sleep(nanoseconds: 120_000_000)
        return job
    }

    func finalize(jobId: UUID, name: String, relation: PersonRelation) async throws -> SoundAsset {
        guard let job = jobs[jobId], job.status == .completed else {
            throw ServiceError.invalidState("处理尚未完成")
        }
        return SoundAsset(
            id: UUID(),
            name: name.isEmpty ? "新的声音种子" : name,
            kind: .seed,
            durationSeconds: 90,
            symbolName: "leaf.fill",
            avatarColor: 0xD79A72,
            isFavorite: false,
            relation: relation,
            createdAt: Date(),
            lastUsedAt: Date(),
            previewResourceName: job.previewResourceName ?? "voice_phrase_mom",
            processingStatus: .ready,
            authorization: VoiceAuthorization(
                confirmed: true,
                revocable: true,
                authorizationId: "auth-\(jobId.uuidString.prefix(8))"
            )
        )
    }
}
