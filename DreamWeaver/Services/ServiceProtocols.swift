import Foundation

protocol ContentService: AnyObject {
    func loadBootstrap() async throws -> BootstrapPayload
    func fetchScenes() async throws -> [DreamScene]
    func fetchScene(id: UUID) async throws -> DreamScene
    func fetchMixPresets(sceneStyle: SceneVisualStyle?) async throws -> [MixPreset]
    func randomGreeting() -> String
    /// Local-only favorite/listen overlay. Remote may no-op until auth APIs are wired.
    func persistSceneOverlay(scenes: [DreamScene]) throws
}

protocol UserLibraryService: AnyObject {
    func fetchAssets() async throws -> [SoundAsset]
    func upsert(_ asset: SoundAsset) async throws
    func delete(id: UUID) async throws
    func deleteImpact(id: UUID) async throws -> LibraryDeleteImpact
    func toggleFavorite(id: UUID) async throws -> SoundAsset
    func rename(id: UUID, name: String) async throws
    func resetToFixture() async throws
}

protocol SeedPipelineService: AnyObject {
    func analyze(durationSeconds: Int) async throws -> SeedQualityReport
    func authorize(confirmed: Bool) async throws
    func startProcess(durationSeconds: Int) async throws -> SeedJob
    func pollJob(id: UUID) async throws -> SeedJob
    func finalize(jobId: UUID, name: String, relation: PersonRelation) async throws -> SoundAsset
}

protocol AnalyticsService: AnyObject {
    func summary() async throws -> UsageRecord
    func record(_ event: AnalyticsEvent) async throws
    func resetDemoStats() async throws
}

@MainActor
protocol PlaybackService: AnyObject {
    var isPlaying: Bool { get }
    var progress: Double { get }
    var lastErrorMessage: String? { get }

    func configureSession() throws
    func load(scene: DreamScene, sources: [SoundSource]) throws
    func play()
    func pause()
    func stop()
    func updateSource(id: UUID, volume: Double, position: SpatialPosition, enabled: Bool)
    func syncSources(_ sources: [SoundSource])
    func preview(resourceName: String?)
    func stopPreview()
    func startSleepTimer(option: TimerOption, onTick: @escaping (Double) -> Void, onFinished: @escaping () -> Void)
    func cancelSleepTimer()
    func performLayeredFade(phases: [FadePhase], onFinished: @escaping () -> Void)
}
