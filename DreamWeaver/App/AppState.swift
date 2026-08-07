import Foundation
import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var selectedTab: AppTab = .now
    @Published var scenes: [DreamScene]
    @Published var currentSceneId: UUID
    @Published var isPlaying = true
    @Published var timerOption: TimerOption = .autoStop
    @Published private(set) var sleepTimerDurationMinutes: Int = 45
    /// Elapsed fraction 0...1 for countdown timer chips.
    @Published private(set) var timerElapsedProgress: Double = 0
    @Published var soundAssets: [SoundAsset]
    @Published var usageRecord: UsageRecord
    @Published var savedMixes: [SavedMix] = []
    @Published var mixPresets: [MixPreset]
    @Published var mixBoardSelection: MixBoardSelection = .mine
    private var personalMixByScene: [UUID: [SoundSource]] = [:]

    @Published var showLaunch = true
    /// Frozen before the first frame so bootstrap hydration cannot recolor the launch animation.
    @Published private(set) var launchScenePalette: ScenePalette
    /// Shown while leaving the foreground so the iOS launch snapshot already matches next boot.
    @Published private(set) var backgroundLaunchPalette: ScenePalette?
    @Published var controlsVisible = true
    @Published var showMixPalette = false
    @Published var sceneTitleVisible = true
    @Published var isTransitioningScene = false

    @Published var reduceMotion: Bool
    @Published var autoPlayEnabled: Bool
    @Published var backgroundPlayEnabled: Bool
    @Published var lockScreenPlayEnabled: Bool
    @Published var animationIntensity: Double
    @Published var darkModeForced: Bool
    @Published var audioQuality: String
    @Published var notificationsEnabled: Bool

    @Published var nickname: String
    @Published var isAppleSignedIn: Bool
    @Published var isMember: Bool
    /// Remote session present (Keychain tokens). Frontend login shell should call `applyRemoteAuth` / `signOutRemote`.
    @Published private(set) var isRemoteAuthenticated = false
    @Published private(set) var sessionUserId: UUID?
    @Published private(set) var privateSceneSummaries: [APIContentDTO.PrivateSceneSummary] = []

    @Published var playbackProgress: Double = 0.22
    @Published var previewingSoundId: UUID?
    @Published var userIsInteracting = false
    @Published var lastServiceMessage: String?
    @Published var showDemoControls = true
    /// Preferred backend stored in UserDefaults; takes effect on next cold start.
    @Published var preferredContentBackend: ServiceBackendMode {
        didSet {
            ServiceBackendConfig.mode = preferredContentBackend
            if preferredContentBackend != contentBackendMode {
                lastServiceMessage = "已切换到\(preferredContentBackend.title)，请完全退出 App 后重开生效"
            }
        }
    }

    let isFirstLaunch: Bool
    let contentService: ContentService
    let libraryService: UserLibraryService
    let analyticsService: AnalyticsService
    let playback: LocalPlaybackService
    let authService: RemoteAuthService?
    let remoteUserService: RemoteUserService?
    /// Optional remote library for upload / playback-url helpers (same instance as `libraryService` when remote).
    let remoteLibraryService: RemoteUserLibraryService?
    /// Frontend-visible: which content backend this process started with.
    let contentBackendMode: ServiceBackendMode

    private let defaults = UserDefaults.standard
    private let store = DemoPersistenceStore.shared
    private var hideTitleTask: Task<Void, Never>?
    private var hideMixPaletteTask: Task<Void, Never>?
    private var sessionStartedAt: Date?
    private var isSleepTimerArmed = false
    /// Maps official scene id → private scene id when home/save links them.
    private var privateSceneIdBySource: [UUID: UUID] = [:]
    /// Warm timelines for swipe targets so playback reload skips a network/disk round-trip.
    private var timelineCache: [UUID: APIContentDTO.SceneTimeline] = [:]
    private var swipePrefetchTasks: [UUID: Task<Void, Never>] = [:]
    /// Official catalog tracks (stable DemoIDs) before personal-mix overlay — used to align presets.
    private var catalogSourcesByScene: [UUID: [SoundSource]] = [:]
    /// Prevents Settings `onChange` → `persistSettings` from racing while hydrating remote prefs.
    private var isApplyingRemoteSettings = false
    private var remoteSettingsSyncTask: Task<Void, Never>?

    private static let preparedLaunchSceneKey = "dw.preparedLaunchScene.v1"

    private struct PreparedLaunchScene: Codable {
        let id: UUID
        let visualStyle: SceneVisualStyle
        let palette: ScenePalette
    }

    convenience init() {
        let mode = ServiceBackendConfig.mode
        let content: ContentService
        let auth: RemoteAuthService?
        let remoteUser: RemoteUserService?
        let library: UserLibraryService
        let remoteLibrary: RemoteUserLibraryService?
        let analytics: AnalyticsService
        switch mode {
        case .remote:
            let client = APIClient.shared
            content = RemoteContentService(client: client)
            auth = RemoteAuthService(client: client)
            remoteUser = RemoteUserService(client: client)
            let remoteLib = RemoteUserLibraryService(client: client)
            library = remoteLib
            remoteLibrary = remoteLib
            analytics = RemoteAnalyticsService(client: client)
        case .local:
            content = LocalContentService()
            auth = nil
            remoteUser = nil
            library = LocalUserLibraryService()
            remoteLibrary = nil
            analytics = LocalAnalyticsService()
        }
        self.init(
            contentService: content,
            libraryService: library,
            analyticsService: analytics,
            playback: LocalPlaybackService(),
            contentBackendMode: mode,
            authService: auth,
            remoteUserService: remoteUser,
            remoteLibraryService: remoteLibrary
        )
    }

    init(
        contentService: ContentService,
        libraryService: UserLibraryService,
        analyticsService: AnalyticsService,
        playback: LocalPlaybackService,
        contentBackendMode: ServiceBackendMode = .local,
        authService: RemoteAuthService? = nil,
        remoteUserService: RemoteUserService? = nil,
        remoteLibraryService: RemoteUserLibraryService? = nil
    ) {
        self.contentService = contentService
        self.libraryService = libraryService
        self.analyticsService = analyticsService
        self.playback = playback
        self.contentBackendMode = contentBackendMode
        self.authService = authService
        self.remoteUserService = remoteUserService
        self.remoteLibraryService = remoteLibraryService

        store.migrateIfNeeded()

        let storedFirst = defaults.object(forKey: "dw.hasLaunched") == nil
        isFirstLaunch = storedFirst
        defaults.set(true, forKey: "dw.hasLaunched")

        reduceMotion = defaults.bool(forKey: "dw.reduceMotion")
        autoPlayEnabled = defaults.object(forKey: "dw.autoPlay") as? Bool ?? true
        backgroundPlayEnabled = defaults.object(forKey: "dw.bgPlay") as? Bool ?? true
        lockScreenPlayEnabled = defaults.object(forKey: "dw.lockPlay") as? Bool ?? true
        animationIntensity = defaults.object(forKey: "dw.animIntensity") as? Double ?? 0.7
        darkModeForced = defaults.object(forKey: "dw.darkMode") as? Bool ?? true
        audioQuality = defaults.string(forKey: "dw.audioQuality") ?? "标准"
        notificationsEnabled = defaults.object(forKey: "dw.notifications") as? Bool ?? false
        nickname = defaults.string(forKey: "dw.nickname") ?? "夜行者"
        isAppleSignedIn = defaults.object(forKey: "dw.appleSignIn") as? Bool ?? true
        isMember = defaults.object(forKey: "dw.member") as? Bool ?? true
        preferredContentBackend = contentBackendMode
        isRemoteAuthenticated = contentBackendMode == .remote && KeychainTokenStore.hasSession
        if let idString = defaults.string(forKey: "dw.sessionUserId") {
            sessionUserId = UUID(uuidString: idString)
        }

        var initialScenes = MockDataService.makeScenes()
        let preparedLaunch = Self.loadPreparedLaunchScene(from: defaults)
        defaults.removeObject(forKey: Self.preparedLaunchSceneKey)

        let preparedIndex = preparedLaunch.flatMap { prepared in
            initialScenes.firstIndex(where: { $0.id == prepared.id })
                ?? initialScenes.firstIndex(where: { $0.visualStyle == prepared.visualStyle })
        }
        if let preparedLaunch, let preparedIndex {
            // Use the persisted palette from the first frame, even before a remote catalog arrives.
            initialScenes[preparedIndex].palette = preparedLaunch.palette
        }
        let initialTarget = preparedIndex.map { initialScenes[$0] }
            ?? initialScenes.randomElement()
            ?? initialScenes[0]

        scenes = initialScenes
        soundAssets = MockDataService.makeSoundAssets()
        usageRecord = MockDataService.makeUsageRecord()
        mixPresets = MockDataService.makeMixPresets()
        mixBoardSelection = .mine
        currentSceneId = initialTarget.id
        launchScenePalette = initialTarget.palette
        backgroundLaunchPalette = nil

        if let mixStore = store.loadPersonalMix() {
            for (key, value) in mixStore.byScene {
                if let id = UUID(uuidString: key) {
                    personalMixByScene[id] = value
                }
            }
        }

        playback.onTimelineSourceChange = { [weak self] id, source in
            self?.applyTimelineSourceChange(id: id, source: source)
        }
        playback.onRendererStateChange = { [weak self] _ in
            guard let self else { return }
            self.playbackProgress = self.playback.progress
        }

        Task { await self.bootstrap() }
    }

    var currentScene: DreamScene {
        scenes.first(where: { $0.id == currentSceneId }) ?? scenes[0]
    }

    var currentSceneIndex: Int {
        scenes.firstIndex(where: { $0.id == currentSceneId }) ?? 0
    }

    /// Official / community presets that belong to the current scene.
    var mixPresetsForCurrentScene: [MixPreset] {
        let styleKey = currentScene.visualStyle.rawValue
        let sceneId = currentSceneId
        return mixPresets.filter { preset in
            // Prefer positive matches; do not hard-fail when scene_id is set but style still matches
            // (covers catalog reseed / id drift during联调).
            if let sid = preset.sceneId, sid == sceneId { return true }
            if let hint = preset.styleHint, !hint.isEmpty, hint == styleKey { return true }
            if !preset.subtitle.isEmpty, preset.subtitle == styleKey { return true }
            if preset.sceneId != nil { return false }
            return legacyPresetMatchesCurrentScene(preset)
        }
    }

    private func legacyPresetMatchesCurrentScene(_ preset: MixPreset) -> Bool {
        switch currentScene.visualStyle {
        case .hairCare:
            return preset.id == DemoIDs.presetHairCare
        case .rainEaves:
            return preset.id == DemoIDs.presetRainFine || preset.id == DemoIDs.presetBreathOnly
        case .himalaya:
            return preset.id == DemoIDs.presetForestGlow
        case .mistTide:
            return preset.id == DemoIDs.presetMistTide
        case .fireplaceWhisper:
            return preset.id == DemoIDs.presetFireplace
        case .starRiver:
            return preset.id == DemoIDs.presetStarRiver
        case .flight:
            return preset.id == DemoIDs.presetBreathOnly
        default:
            return false
        }
    }

    // MARK: - Bootstrap

    func bootstrap() async {
        do {
            // Capture the scene chosen synchronously during initialization so the
            // launch overlay and the scene revealed beneath it share one target.
            let coldLaunchTarget = currentScene

            // Drop cached timelines so catalog reseeds (v6→v8) take effect in-process.
            timelineCache.removeAll()
            swipePrefetchTasks.values.forEach { $0.cancel() }
            swipePrefetchTasks.removeAll()

            if contentBackendMode == .remote {
                _ = try await contentService.loadBootstrap()
            }

            var loadedScenes = try await contentService.fetchScenes()
            let createdScenes = store.loadCreatedScenes()
            let createdIDs = Set(createdScenes.map(\.id))
            loadedScenes.removeAll { createdIDs.contains($0.id) }
            loadedScenes.insert(contentsOf: createdScenes, at: 0)
            scenes = loadedScenes
            catalogSourcesByScene = Dictionary(
                uniqueKeysWithValues: loadedScenes.map { ($0.id, $0.soundSources) }
            )
            // Library / analytics must not block home favorites + settings hydration.
            if let assets = try? await libraryService.fetchAssets() {
                soundAssets = assets
            }
            if let summary = try? await analyticsService.summary() {
                usageRecord = summary
            }
            do {
                mixPresets = try await contentService.fetchMixPresets(sceneStyle: nil)
            } catch {
                // Keep Mock presets so「洗头轻声 / 细雨慢听」chips remain available offline.
                lastServiceMessage = "混音预设加载失败：\(error.localizedDescription)"
            }

            // The cold-launch target is chosen once in init. Keep the same ID after
            // catalog hydration; if a backend replaced IDs, preserve its visual style.
            if !loadedScenes.contains(where: { $0.id == currentSceneId }) {
                let resolvedTarget = loadedScenes.first {
                    $0.visualStyle == coldLaunchTarget.visualStyle
                } ?? loadedScenes.randomElement()
                if let resolvedTarget {
                    currentSceneId = resolvedTarget.id
                }
            }

            // Drop / repair stale personal mixes that no longer share official track IDs.
            for scene in loadedScenes {
                reconcilePersonalMix(
                    with: scene,
                    enforceOfficialVoiceScope: !createdIDs.contains(scene.id)
                )
            }

            if let personal = personalMixByScene[currentSceneId] {
                mutateCurrentSources { $0 = personal }
            } else {
                personalMixByScene[currentSceneId] = currentScene.soundSources
            }

            if contentBackendMode == .remote, KeychainTokenStore.hasSession {
                await refreshAuthenticatedRemoteState()
            } else {
                isRemoteAuthenticated = false
            }

            reloadPlayback(autoPlay: autoPlayEnabled)
        } catch {
            lastServiceMessage = error.localizedDescription
        }
    }

    // MARK: - Remote auth (UI shell stays with frontend; these are AppState entry points)

    /// Call after Sign in with Apple (or any path that already obtained tokens via `RemoteAuthService`).
    func applyRemoteAuth(_ tokens: APIContentDTO.AuthTokens) async {
        sessionUserId = tokens.user_id
        nickname = tokens.nickname
        isAppleSignedIn = true
        isRemoteAuthenticated = true
        defaults.set(tokens.user_id.uuidString, forKey: "dw.sessionUserId")
        persistSettingsLocally()
        // Upload current device prefs first so a fresh account inherits them, then re-hydrate.
        await pushSettingsToRemote()
        await refreshAuthenticatedRemoteState()
        if let assets = try? await libraryService.fetchAssets() {
            soundAssets = assets
        }
        lastServiceMessage = "已登录：\(tokens.nickname)"
    }

    /// Frontend: pass Apple identity token (+ optional nonce).
    func signInWithApple(
        identityToken: String,
        nickname: String? = nil,
        nonce: String? = nil
    ) async {
        guard let authService else {
            lastServiceMessage = "当前为本地演示模式，无法远程登录"
            return
        }
        do {
            let tokens = try await authService.signInWithApple(
                identityToken: identityToken,
                nickname: nickname ?? self.nickname,
                nonce: nonce
            )
            await applyRemoteAuth(tokens)
        } catch {
            lastServiceMessage = error.localizedDescription
        }
    }

    /// Demo / smoke login without Apple UI (`dev:<sub>`).
    func signInWithDevAccount(sub: String = "demo-user") async {
        guard let authService else {
            lastServiceMessage = "当前为本地演示模式，无法远程登录"
            return
        }
        do {
            let tokens = try await authService.signInWithDevToken(sub: sub, nickname: nickname)
            await applyRemoteAuth(tokens)
        } catch {
            lastServiceMessage = error.localizedDescription
        }
    }

    func signOutRemote() async {
        if let authService {
            try? await authService.logout()
        } else {
            KeychainTokenStore.clear()
        }
        isRemoteAuthenticated = false
        sessionUserId = nil
        privateSceneSummaries = []
        privateSceneIdBySource = [:]
        defaults.removeObject(forKey: "dw.sessionUserId")
        lastServiceMessage = "已退出远程登录"
    }

    private func refreshAuthenticatedRemoteState() async {
        guard let remoteUserService, KeychainTokenStore.hasSession else {
            isRemoteAuthenticated = false
            return
        }
        isRemoteAuthenticated = true
        do {
            if let settings = try? await remoteUserService.fetchSettings() {
                applyRemoteSettings(settings)
            }
            let home = try await remoteUserService.fetchHome()
            applyHome(home)
        } catch {
            if case ServiceError.unauthorized = error {
                isRemoteAuthenticated = false
                KeychainTokenStore.clear()
            }
            lastServiceMessage = error.localizedDescription
        }
    }

    private func applyHome(_ home: APIContentDTO.Home) {
        let favoriteIds = Set(home.favorites.map(\.id))
        for i in scenes.indices {
            scenes[i].isFavorite = favoriteIds.contains(scenes[i].id)
        }
        privateSceneSummaries = home.private_scenes
        privateSceneIdBySource = Dictionary(
            uniqueKeysWithValues: home.private_scenes.compactMap { summary in
                guard let source = summary.source_scene_id else { return nil }
                return (source, summary.id)
            }
        )
    }

    private func applyRemoteSettings(_ settings: APIContentDTO.Settings) {
        isApplyingRemoteSettings = true
        defer { isApplyingRemoteSettings = false }

        if let v = settings.reduce_motion { reduceMotion = v }
        if let v = settings.auto_play_enabled { autoPlayEnabled = v }
        if let v = settings.background_play_enabled { backgroundPlayEnabled = v }
        if let v = settings.lock_screen_play_enabled { lockScreenPlayEnabled = v }
        if let v = settings.animation_intensity { animationIntensity = v }
        if let v = settings.dark_mode_forced { darkModeForced = v }
        if let v = settings.audio_quality { audioQuality = v }
        if let v = settings.notifications_enabled { notificationsEnabled = v }
        // Mirror hydrated remote prefs into UserDefaults without a remote PUT loop.
        persistSettingsLocally()
    }

    /// Restores fixture data for filming. Call before each take.
    func resetDemoState() {
        store.resetAllDemoKeys()
        scenes = MockDataService.makeScenes()
        catalogSourcesByScene = Dictionary(
            uniqueKeysWithValues: scenes.map { ($0.id, $0.soundSources) }
        )
        timelineCache.removeAll()
        soundAssets = MockDataService.makeSoundAssets()
        usageRecord = MockDataService.makeUsageRecord()
        mixPresets = MockDataService.makeMixPresets()
        personalMixByScene = [:]
        savedMixes = []
        currentSceneId = DemoIDs.hairCareScene
        timerOption = .autoStop
        sleepTimerDurationMinutes = 45
        timerElapsedProgress = 0
        playback.cancelSleepTimer()
        isSleepTimerArmed = false
        mixBoardSelection = .mine
        personalMixByScene[currentSceneId] = currentScene.soundSources
        lastServiceMessage = "已重置为标准演示状态"
        reloadPlayback(autoPlay: autoPlayEnabled)
        Task {
            try? await libraryService.resetToFixture()
            try? await analyticsService.resetDemoStats()
            try? contentService.persistSceneOverlay(scenes: scenes)
        }
    }

    // MARK: - Launch

    /// Select and persist the next cold-launch scene before iOS captures the background snapshot.
    func prepareNextLaunchScene() {
        guard backgroundLaunchPalette == nil else { return }

        let createdSceneIDs = Set(store.loadCreatedScenes().map(\.id))
        let officialScenes = scenes.filter { !createdSceneIDs.contains($0.id) }
        let alternatives = officialScenes.filter { $0.id != currentSceneId }
        guard let nextScene = alternatives.randomElement() ?? officialScenes.randomElement() else {
            return
        }

        let prepared = PreparedLaunchScene(
            id: nextScene.id,
            visualStyle: nextScene.visualStyle,
            palette: nextScene.palette
        )
        if let data = try? JSONEncoder().encode(prepared) {
            defaults.set(data, forKey: Self.preparedLaunchSceneKey)
        }
        backgroundLaunchPalette = nextScene.palette
    }

    /// Returning from Control Center / app switching should reveal the current session unchanged.
    func resumeFromBackground() {
        backgroundLaunchPalette = nil
    }

    private static func loadPreparedLaunchScene(from defaults: UserDefaults) -> PreparedLaunchScene? {
        guard let data = defaults.data(forKey: preparedLaunchSceneKey) else { return nil }
        return try? JSONDecoder().decode(PreparedLaunchScene.self, from: data)
    }

    func finishLaunch() {
        // Overlay is already fully transparent; drop it without a second fade of「此刻」.
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            showLaunch = false
        }
        showSceneTitleTemporarily()
        if autoPlayEnabled {
            playback.play()
            isPlaying = playback.isPlaying
            if isPlaying, !isSleepTimerArmed {
                armSelectedSleepTimer(resetProgress: true)
            }
        }
        sessionStartedAt = Date()
    }

    // MARK: - Playback

    func togglePlayback() {
        if isPlaying {
            isPlaying = false
            playback.pause()
        } else {
            playback.play()
            isPlaying = playback.isPlaying
            if isPlaying, !isSleepTimerArmed {
                armSelectedSleepTimer(resetProgress: true)
            }
        }
        bumpInteraction()
    }

    func setTimerOption(_ option: TimerOption) {
        timerOption = option
        if let minutes = option.minutes {
            sleepTimerDurationMinutes = minutes
        }
        armSelectedSleepTimer(resetProgress: true)
    }

    func setSleepTimerDuration(minutes: Int) {
        let clampedMinutes = min(max(minutes, 5), 120)
        sleepTimerDurationMinutes = clampedMinutes
        switch clampedMinutes {
        case 10: timerOption = .tenMinutes
        case 30: timerOption = .thirtyMinutes
        case 60: timerOption = .oneHour
        default: timerOption = .autoStop
        }
        armSleepTimer(
            duration: TimeInterval(clampedMinutes * 60),
            usesAcceleratedFade: false,
            resetProgress: true
        )
    }

    private func armSelectedSleepTimer(resetProgress: Bool) {
        armSleepTimer(
            duration: timerOption.countdownSeconds,
            usesAcceleratedFade: timerOption == .demoAccelerated,
            resetProgress: resetProgress
        )
    }

    private func armSleepTimer(
        duration: TimeInterval?,
        usesAcceleratedFade: Bool,
        resetProgress: Bool
    ) {
        playback.cancelSleepTimer()
        isSleepTimerArmed = false
        if resetProgress {
            timerElapsedProgress = 0
        }

        guard let duration, duration > 0 else { return }
        isSleepTimerArmed = true

        playback.startSleepTimer(
            duration: duration,
            usesAcceleratedFade: usesAcceleratedFade,
            onTick: { [weak self] progress in
                self?.timerElapsedProgress = progress
            },
            onFinished: { [weak self] in
                guard let self else { return }
                // PlaybackService already paused; keep UI flag in sync.
                self.isSleepTimerArmed = false
                self.isPlaying = false
                self.timerElapsedProgress = 1
                self.recordSessionEnd()
            }
        )
    }

    private func reloadPlayback(autoPlay: Bool) {
        let scene = currentScene
        // Pass every resource-backed track (including disabled). Official timelines
        // enable/fade layers over time; filtering to isEnabled left rain eaves with
        // only 远雨 and made all later cues no-ops.
        let sources = scene.soundSources.filter { $0.resourceName != nil }
        let sceneId = currentSceneId
        Task { @MainActor [weak self] in
            guard let self else { return }
            var renderPlan: SceneRenderPlan?
            let timeline: APIContentDTO.SceneTimeline?
            if let composition = self.store.loadCreatedComposition(sceneId: sceneId) {
                renderPlan = ScenePlanCompiler.compile(
                    composition: composition,
                    sceneID: sceneId
                )
                timeline = nil
            } else if let cached = self.timelineCache[sceneId] {
                timeline = cached
            } else if let fetched = try? await self.contentService.fetchTimeline(sceneId: sceneId) {
                self.timelineCache[sceneId] = fetched
                timeline = fetched
            } else {
                timeline = nil
            }
            do {
                self.isSleepTimerArmed = false
                if let renderPlan {
                    try self.playback.load(scene: scene, plan: renderPlan)
                } else {
                    try self.playback.load(scene: scene, sources: sources, timeline: timeline)
                }
                self.playbackProgress = self.playback.progress
                if autoPlay {
                    self.playback.play()
                    self.isPlaying = self.playback.isPlaying
                    if self.isPlaying {
                        self.armSelectedSleepTimer(resetProgress: true)
                    }
                } else {
                    self.isPlaying = false
                }
                if let message = self.playback.lastErrorMessage {
                    self.lastServiceMessage = message
                }
            } catch {
                self.isPlaying = false
                self.lastServiceMessage = error.localizedDescription
            }
        }
    }

    private func pushSpatialToPlayback() {
        playback.syncSources(currentScene.soundSources)
        playbackProgress = playback.progress
    }

    private func pushSourceToPlayback(id: UUID) {
        guard let source = currentScene.soundSources.first(where: { $0.id == id }) else { return }
        playback.updateSource(
            id: source.id,
            position: source.position,
            enabled: source.isEnabled
        )
        playbackProgress = playback.progress
    }

    /// Frontend/backend: user mix edit exits timeline automation for this track only.
    private func noteManualMixOverride(trackId: UUID) {
        playback.markManualOverride(trackId: trackId)
    }

    /// Mirror timeline automation onto the mix disk. Does not persist personal mix or mark overrides.
    private func applyTimelineSourceChange(id: UUID, source: SoundSource) {
        // Only suppress position while dragging the disk. `userIsInteracting` also covers
        // preset-chip taps (markMixInteraction ~500ms) and would drop t=0 set_position cues.
        let appliedPosition = !isMixDragging
        mutateCurrentSources { sources in
            if let i = sources.firstIndex(where: { $0.id == id }) {
                if appliedPosition {
                    sources[i].position = source.position
                }
                sources[i].isEnabled = source.isEnabled
                if sources[i].resourceName == nil {
                    sources[i].resourceName = source.resourceName
                }
            } else {
                // Official renderer activated a source group missing from the personal overlay.
                sources.append(source)
            }
        }
    }

    // MARK: - Controls visibility

    /// Single entry point so disk / chrome / tab bar share one visibility flag.
    /// Animation is applied in RootTabView / NowView via `DreamTheme.chromeVisibilityAnimation`.
    private func setControlsVisible(_ visible: Bool) {
        controlsVisible = visible
        if !visible {
            showMixPalette = false
        }
    }

    func toggleControlsVisibility() {
        setControlsVisible(!controlsVisible)
        if !controlsVisible {
            hideMixPaletteTask?.cancel()
        }
    }

    func revealControls() {
        setControlsVisible(true)
        if showMixPalette {
            scheduleHideMixPalette()
        }
    }

    func bumpInteraction() {
        userIsInteracting = true
        revealControls()
        Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            userIsInteracting = false
            if showMixPalette {
                scheduleHideMixPalette()
            }
        }
    }

    // MARK: - Scene title

    func showSceneTitleTemporarily() {
        withAnimation(.easeInOut(duration: 0.6)) {
            sceneTitleVisible = true
        }
        hideTitleTask?.cancel()
        hideTitleTask = Task {
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 1.2)) {
                sceneTitleVisible = false
            }
        }
    }

    // MARK: - Mix palette

    private var isMixDragging = false

    /// Show palette as soon as a source (or palette chip) is dragged.
    func beginMixDrag() {
        isMixDragging = true
        hideMixPaletteTask?.cancel()
        guard !(showMixPalette && controlsVisible) else { return }
        withAnimation(DreamTheme.chromeVisibilityAnimation) {
            showMixPalette = true
            controlsVisible = true
        }
    }

    /// After drag ends, wait before returning to the timer chrome.
    func endMixDrag() {
        isMixDragging = false
        scheduleHideMixPalette()
    }

    func openMixPalette() {
        withAnimation(DreamTheme.chromeVisibilityAnimation) {
            showMixPalette = true
            controlsVisible = true
        }
        scheduleHideMixPalette()
    }

    func closeMixPalette() {
        hideMixPaletteTask?.cancel()
        isMixDragging = false
        withAnimation(DreamTheme.chromeVisibilityAnimation) {
            showMixPalette = false
        }
    }

    func scheduleHideMixPalette() {
        hideMixPaletteTask?.cancel()
        guard !isMixDragging else { return }
        hideMixPaletteTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled, showMixPalette, !isMixDragging, !userIsInteracting else { return }
            withAnimation(DreamTheme.chromeVisibilityAnimation) {
                showMixPalette = false
            }
        }
    }

    func markMixInteraction() {
        userIsInteracting = true
        if !controlsVisible {
            setControlsVisible(true)
        }
        if showMixPalette {
            if !isMixDragging {
                scheduleHideMixPalette()
            }
        }
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            userIsInteracting = false
            if showMixPalette {
                if !isMixDragging {
                    scheduleHideMixPalette()
                }
            }
        }
    }

    // MARK: - Scene switching

    /// Prefetch cover + timeline for a likely swipe target (short-video style).
    func prefetchSwipeScene(_ sceneId: UUID) {
        guard scenes.contains(where: { $0.id == sceneId }) else { return }
        if let scene = scenes.first(where: { $0.id == sceneId }) {
            SceneCoverArt.preload(for: scene.visualStyle)
        }
        guard timelineCache[sceneId] == nil else { return }
        swipePrefetchTasks[sceneId]?.cancel()
        swipePrefetchTasks[sceneId] = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.swipePrefetchTasks[sceneId] = nil }
            if let timeline = try? await self.contentService.fetchTimeline(sceneId: sceneId) {
                guard !Task.isCancelled else { return }
                self.timelineCache[sceneId] = timeline
            }
        }
    }

    func enterDream(sceneId: UUID) {
        recordListening(sceneId: sceneId)

        let fadeOut = reduceMotion ? 0.18 : 0.75
        let hold = reduceMotion ? 0.08 : 0.28
        let fadeIn = reduceMotion ? 0.2 : 0.9

        withAnimation(.easeInOut(duration: fadeOut)) {
            isTransitioningScene = true
            controlsVisible = false
            showMixPalette = false
            sceneTitleVisible = false
        }

        Task {
            try? await Task.sleep(nanoseconds: UInt64(fadeOut * 1_000_000_000))

            applySceneSwitch(sceneId: sceneId, ensureNowTab: true)

            try? await Task.sleep(nanoseconds: UInt64(hold * 1_000_000_000))

            withAnimation(.easeInOut(duration: fadeIn)) {
                isTransitioningScene = false
            }

            try? await Task.sleep(nanoseconds: UInt64((fadeIn * 0.35) * 1_000_000_000))
            showSceneTitleTemporarily()
            revealControls()
        }
    }

    /// Short-video swipe: no curtain / opacity refresh — only title re-announces.
    func swipeIntoDream(sceneId: UUID) {
        guard sceneId != currentSceneId else { return }
        recordListening(sceneId: sceneId)
        showMixPalette = false
        // Don't replay disk intro / chrome bloom on swipe handoff.
        skipNextSceneChromeIntro = true
        applySceneSwitch(sceneId: sceneId, ensureNowTab: false)
        withAnimation(.easeOut(duration: 0.12)) {
            sceneTitleVisible = false
        }
        showSceneTitleTemporarily()
    }

    /// Consumed by Now mix chrome when scene id changes mid-swipe.
    private(set) var skipNextSceneChromeIntro = false

    @discardableResult
    func consumeSkipSceneChromeIntro() -> Bool {
        guard skipNextSceneChromeIntro else { return false }
        skipNextSceneChromeIntro = false
        return true
    }

    private func applySceneSwitch(sceneId: UUID, ensureNowTab: Bool) {
        currentSceneId = sceneId
        playbackProgress = 0.08
        mixBoardSelection = .mine
        if let personal = personalMixByScene[sceneId] {
            mutateCurrentSources { $0 = personal }
        } else {
            personalMixByScene[sceneId] = currentScene.soundSources
        }

        if ensureNowTab {
            withAnimation(.easeInOut(duration: reduceMotion ? 0.15 : 0.45)) {
                selectedTab = .now
            }
        }
        reloadPlayback(autoPlay: true)
        sessionStartedAt = Date()
    }

    func toggleFavorite(sceneId: UUID) {
        guard let idx = scenes.firstIndex(where: { $0.id == sceneId }) else { return }
        scenes[idx].isFavorite.toggle()
        let favored = scenes[idx].isFavorite
        try? contentService.persistSceneOverlay(scenes: scenes)
        bumpInteraction()
        guard contentBackendMode == .remote, isRemoteAuthenticated, let remoteUserService else { return }
        Task {
            do {
                let state = try await remoteUserService.patchSceneState(
                    sceneId: sceneId,
                    isFavorite: favored
                )
                if let i = scenes.firstIndex(where: { $0.id == sceneId }) {
                    scenes[i].isFavorite = state.is_favorite
                }
            } catch {
                if let i = scenes.firstIndex(where: { $0.id == sceneId }) {
                    scenes[i].isFavorite = !favored
                    try? contentService.persistSceneOverlay(scenes: scenes)
                }
                lastServiceMessage = "收藏同步失败：\(error.localizedDescription)"
            }
        }
    }

    func recordListening(sceneId: UUID) {
        guard let idx = scenes.firstIndex(where: { $0.id == sceneId }) else { return }
        scenes[idx].listenCount += 1
        refreshFrequentScenes()
        usageRecord.lastUsedAt = Date()
        try? contentService.persistSceneOverlay(scenes: scenes)
        Task {
            try? await analyticsService.record(.sceneListen(sceneId: sceneId))
            if let summary = try? await analyticsService.summary() {
                usageRecord = summary
            }
        }
        guard contentBackendMode == .remote, isRemoteAuthenticated, let remoteUserService else { return }
        Task {
            try? await remoteUserService.patchSceneState(sceneId: sceneId, markOpened: true)
        }
    }

    func refreshFrequentScenes() {
        scenes = MockDataService.markTopFrequentScenes(scenes)
    }

    private func recordSessionEnd() {
        let seconds: Int
        if let started = sessionStartedAt {
            seconds = max(Int(Date().timeIntervalSince(started)), 30)
        } else {
            seconds = 60
        }
        Task {
            try? await analyticsService.record(.sessionEnded(sceneId: currentSceneId, durationSeconds: seconds))
            if let summary = try? await analyticsService.summary() {
                usageRecord = summary
            }
        }
    }

    // MARK: - Sound mix

    func updateSourcePlacement(id: UUID, position: SpatialPosition) {
        guard mixBoardSelection.isMine else { return }
        mutateCurrentSources { sources in
            if let i = sources.firstIndex(where: { $0.id == id }) {
                sources[i].position = position
                sources[i].isEnabled = true
            }
        }
        syncPersonalMixFromScene()
        pushSourceToPlayback(id: id)
        noteManualMixOverride(trackId: id)
        markMixInteraction()
        Task { try? await analyticsService.record(.mixEdited(sceneId: currentSceneId)) }
    }

    func toggleSource(id: UUID) {
        guard mixBoardSelection.isMine else { return }
        mutateCurrentSources { sources in
            if let i = sources.firstIndex(where: { $0.id == id }) {
                sources[i].isEnabled.toggle()
            }
        }
        syncPersonalMixFromScene()
        pushSpatialToPlayback()
        noteManualMixOverride(trackId: id)
        markMixInteraction()
    }

    func removeSource(id: UUID) {
        guard mixBoardSelection.isMine else { return }
        mutateCurrentSources { sources in
            sources.removeAll { $0.id == id }
        }
        syncPersonalMixFromScene()
        pushSpatialToPlayback()
        noteManualMixOverride(trackId: id)
        markMixInteraction()
    }

    func addSource(_ source: SoundSource) {
        guard mixBoardSelection.isMine else { return }
        mutateCurrentSources { sources in
            // Product rule: one voice track per scene; natural layers may stack.
            if source.layer == .voice {
                sources.removeAll { $0.layer == .voice }
            }
            sources.append(source)
        }
        syncPersonalMixFromScene()
        pushSpatialToPlayback()
        noteManualMixOverride(trackId: source.id)
        markMixInteraction()
    }

    func restoreDefaultMix() {
        guard mixBoardSelection.isMine else { return }
        let catalog = catalogSourcesByScene[currentSceneId]
            ?? MockDataService.makeScenes().first(where: { $0.id == currentSceneId })?.soundSources
            ?? MockDataService.makeScenes().first(where: { $0.name == currentScene.name })?.soundSources
        if let original = catalog {
            mutateCurrentSources { $0 = sourcesAlignedToOfficialTracks(original, forceEnabled: false) }
            syncPersonalMixFromScene()
            reloadPlayback(autoPlay: isPlaying || autoPlayEnabled)
        }
        markMixInteraction()
    }

    func selectMineMixBoard() {
        if case .preset = mixBoardSelection {
            ensurePersonalMixSeededIfNeeded()
            if let personal = personalMixByScene[currentSceneId] {
                withAnimation(.easeInOut(duration: 0.3)) {
                    mutateCurrentSources { $0 = personal }
                }
                reloadPlayback(autoPlay: isPlaying || autoPlayEnabled)
            }
        }
        mixBoardSelection = .mine
        markMixInteraction()
    }

    func selectMixPreset(_ preset: MixPreset) {
        if mixBoardSelection.isMine {
            syncPersonalMixFromScene()
        }
        // Overlay preset volumes/positions onto the full catalog so timeline cues can still
        // enable/disable and move tracks. Forcing every preset chip on hid add/remove.
        let fresh = sourcesOverlayingPresetOnCatalog(preset.sources)
        withAnimation(.easeInOut(duration: 0.35)) {
            mutateCurrentSources { $0 = fresh }
            mixBoardSelection = .preset(preset.id)
        }
        reloadPlayback(autoPlay: true)
        markMixInteraction()
    }

    func applyMixPreset(_ preset: MixPreset) {
        selectMixPreset(preset)
    }

    private func ensurePersonalMixSeededIfNeeded() {
        if personalMixByScene[currentSceneId] == nil {
            personalMixByScene[currentSceneId] = currentScene.soundSources
        }
    }

    /// Replaces or repairs a stored personal mix when it drifts from the official catalog.
    private func reconcilePersonalMix(
        with scene: DreamScene,
        enforceOfficialVoiceScope: Bool
    ) {
        let official = scene.soundSources
        guard var personal = personalMixByScene[scene.id] else {
            personalMixByScene[scene.id] = official
            return
        }
        if enforceOfficialVoiceScope {
            let legacyResourceNames: Set<String>
            switch scene.id {
            case DemoIDs.hairCareScene:
                legacyResourceNames = [
                    "hair_dryer",
                    "hair_wash",
                    "hair_wash_care_spray",
                    "hair_wash_care_tool",
                    "hair_wash_scalp_massage",
                    "voice_phrase_mom",
                ]
            case DemoIDs.rainEavesScene:
                legacyResourceNames = ["wind_realistic", "rain_soft_legacy"]
            default:
                legacyResourceNames = []
            }
            let officialIDs = Set(official.map(\.id))
            var scoped = personal.filter { $0.layer != .voice }
            scoped.removeAll { source in
                !officialIDs.contains(source.id)
                    && source.resourceName.map(legacyResourceNames.contains) == true
            }
            if scene.id == DemoIDs.hairCareScene,
               let officialVoice = official.first(where: { $0.layer == .voice }) {
                // The timeline requires the canonical track ID and resource key.
                scoped.append(officialVoice)
            }

            // Preserve the user's position/enabled state, but always rebind an
            // official track to the current catalog metadata and mastered file.
            // This repairs mixes persisted before a preset package upgrade.
            let canonicalByID = Dictionary(
                uniqueKeysWithValues: official.map { ($0.id, $0) }
            )
            for index in scoped.indices {
                guard let canonical = canonicalByID[scoped[index].id] else { continue }
                scoped[index].name = canonical.name
                scoped[index].symbolName = canonical.symbolName
                scoped[index].assetId = canonical.assetId
                scoped[index].resourceName = canonical.resourceName
                scoped[index].layer = canonical.layer
            }
            if scoped != personal {
                personal = scoped
                personalMixByScene[scene.id] = scoped
                persistPersonalMix()
            }
        }
        let remoteKeys = Set(official.compactMap(\.resourceName))
        guard !remoteKeys.isEmpty else { return }
        let personalKeys = Set(personal.compactMap(\.resourceName))
        let officialResourceIds = Set(official.filter { $0.resourceName != nil }.map(\.id))
        let personalIds = Set(personal.map(\.id))
        let missingOfficialTracks = !officialResourceIds.isSubset(of: personalIds)
        if personalKeys.isEmpty || personalKeys.isDisjoint(with: remoteKeys) {
            personalMixByScene[scene.id] = official
            persistPersonalMix()
            return
        }
        if missingOfficialTracks {
            var merged = personal
            for track in official where track.resourceName != nil {
                if merged.contains(where: { $0.id == track.id }) { continue }
                merged.removeAll { $0.resourceName == track.resourceName }
                merged.append(track)
            }
            personalMixByScene[scene.id] = merged
            persistPersonalMix()
        }
    }

    /// Map preset / restore sources onto catalog track IDs by `resourceName` (timeline-safe).
    private func sourcesAlignedToOfficialTracks(
        _ sources: [SoundSource],
        forceEnabled: Bool
    ) -> [SoundSource] {
        let catalog = catalogSourcesByScene[currentSceneId] ?? currentScene.soundSources
        var idByResource: [String: UUID] = [:]
        var catalogById: [UUID: SoundSource] = [:]
        for track in catalog {
            catalogById[track.id] = track
            if let key = track.resourceName {
                idByResource[key] = track.id
            }
        }
        return sources.map { source in
            let resolvedId = source.resourceName.flatMap { idByResource[$0] } ?? source.id
            // Remote seed presets historically omit `position`, which decodes as `.default`
            // (angle 0 / radius 0.55) and stacks every chip on the right of the disk.
            let position: SpatialPosition
            if source.position == .default, let catalogPos = catalogById[resolvedId]?.position,
               catalogPos != .default {
                position = catalogPos
            } else {
                position = source.position
            }
            return SoundSource(
                id: resolvedId,
                name: source.name,
                symbolName: source.symbolName,
                isEnabled: forceEnabled ? true : source.isEnabled,
                initialEnvelope: source.initialEnvelope,
                position: position,
                assetId: source.assetId,
                resourceName: source.resourceName,
                layer: source.layer
            )
        }
    }

    /// Apply preset mix character onto the official catalog without collapsing the timeline track set.
    private func sourcesOverlayingPresetOnCatalog(_ presetSources: [SoundSource]) -> [SoundSource] {
        let catalog = catalogSourcesByScene[currentSceneId] ?? currentScene.soundSources
        let aligned = sourcesAlignedToOfficialTracks(presetSources, forceEnabled: false)
        var overlayByResource: [String: SoundSource] = [:]
        for source in aligned {
            if let key = source.resourceName {
                overlayByResource[key] = source
            }
        }
        return catalog.map { track in
            guard let key = track.resourceName, let overlay = overlayByResource[key] else {
                return track
            }
            let position = overlay.position == .default ? track.position : overlay.position
            return SoundSource(
                id: track.id,
                name: overlay.name,
                symbolName: overlay.symbolName,
                // Keep catalog enable flags so timeline can reveal / hide chips over time.
                isEnabled: track.isEnabled,
                initialEnvelope: track.initialEnvelope,
                position: position,
                assetId: overlay.assetId ?? track.assetId,
                resourceName: track.resourceName,
                layer: overlay.layer
            )
        }
    }

    private func syncPersonalMixFromScene() {
        guard mixBoardSelection.isMine else { return }
        personalMixByScene[currentSceneId] = currentScene.soundSources
        persistPersonalMix()
    }

    private func persistPersonalMix() {
        let encoded = DemoPersistenceStore.PersonalMixStore(
            byScene: Dictionary(uniqueKeysWithValues: personalMixByScene.map { ($0.key.uuidString, $0.value) })
        )
        try? store.savePersonalMix(encoded)
    }

    func saveCurrentMix() {
        let mix = SavedMix(
            id: UUID(),
            name: "\(currentScene.name) · 组合",
            sceneId: currentSceneId,
            sources: currentScene.soundSources,
            savedAt: Date()
        )
        savedMixes.insert(mix, at: 0)
        markMixInteraction()
        // Explicit remote save only when authenticated — never auto on drag.
        guard contentBackendMode == .remote, isRemoteAuthenticated else { return }
        Task { await saveCurrentMixToRemote(name: mix.name) }
    }

    /// Saves a Create-editor result as a reusable personal scene shown in the existing scene library.
    @discardableResult
    func saveCreatedScene(
        id: UUID,
        name: String,
        sourceSceneId: UUID?,
        soundSources: [SoundSource],
        composition: APIContentDTO.SceneComposition? = nil
    ) throws -> DreamScene {
        let base = sourceSceneId.flatMap { sourceID in
            scenes.first { $0.id == sourceID }
        } ?? currentScene
        let manifestTracks = soundSources.compactMap { source -> AudioTrackRef? in
            guard let resourceName = source.resourceName else { return nil }
            return AudioTrackRef(
                id: source.id,
                name: source.name,
                symbolName: source.symbolName,
                resourceName: resourceName,
                layer: source.layer,
                loops: source.layer != .voice && source.layer != .trigger,
                initialEnvelope: source.initialEnvelope,
                defaultPosition: source.position,
                isRequired: false
            )
        }
        let scene = DreamScene(
            id: id,
            name: name,
            subtitle: "个人场景 · \(soundSources.count) 个声源",
            description: "基于「\(base.name)」保存的个人场景。",
            category: base.category,
            tags: Array(Set(base.tags + ["个人场景"])).sorted(),
            palette: base.palette,
            soundSources: soundSources,
            isFavorite: false,
            isFrequentlyUsed: false,
            listenCount: 0,
            mockListenerCount: 0,
            visualStyle: base.visualStyle,
            isDemoPlayable: !manifestTracks.isEmpty,
            audioManifest: manifestTracks.isEmpty
                ? nil
                : SceneAudioManifest(
                    tracks: manifestTracks,
                    voicePhraseResourceName: soundSources.first(where: { $0.layer == .voice })?.resourceName
                )
        )

        let previousScene = scenes.first { $0.id == id }
        if let index = scenes.firstIndex(where: { $0.id == id }) {
            scenes[index] = scene
        } else {
            scenes.insert(scene, at: 0)
        }

        var createdScenes = store.loadCreatedScenes()
        createdScenes.removeAll { $0.id == id }
        createdScenes.insert(scene, at: 0)
        let previousComposition = store.loadCreatedComposition(sceneId: id)
        do {
            try store.saveCreatedComposition(composition, sceneId: id)
            try store.saveCreatedScenes(createdScenes)
        } catch {
            try? store.saveCreatedComposition(previousComposition, sceneId: id)
            scenes.removeAll { $0.id == id }
            if let previousScene {
                scenes.insert(previousScene, at: 0)
            }
            throw error
        }
        if let composition, composition.schema != "scene_composition_v2" {
            timelineCache[id] = SceneCompositionTimelineMapper.timeline(
                from: composition,
                sceneId: id
            )
        } else {
            timelineCache[id] = nil
        }
        return scene
    }

    /// Explicit cloud save for frontend confirm dialogs.
    func saveCurrentMixToRemote(name: String? = nil) async {
        guard let remoteUserService, isRemoteAuthenticated else {
            lastServiceMessage = "需要远程登录后才能云端保存"
            return
        }
        let mixName = name ?? "\(currentScene.name) · 组合"
        let sources = currentScene.soundSources
        do {
            let detail: APIContentDTO.PrivateSceneDetail
            if let existingId = privateSceneIdBySource[currentSceneId]
                ?? privateSceneSummaries.first(where: { $0.source_scene_id == currentSceneId })?.id {
                detail = try await remoteUserService.updateDraftAndSave(
                    privateSceneId: existingId,
                    name: mixName,
                    sources: sources
                )
            } else {
                detail = try await remoteUserService.createAndSaveMix(
                    name: mixName,
                    scene: currentScene,
                    sources: sources
                )
                privateSceneIdBySource[currentSceneId] = detail.id
            }
            if let listed = try? await remoteUserService.listPrivateScenes() {
                privateSceneSummaries = listed
            }
            lastServiceMessage = "已保存「\(detail.name)」v\(detail.saved_version)"
        } catch {
            lastServiceMessage = error.localizedDescription
        }
    }

    /// Create Tab: upsert composition as remote **draft** (not published saved version).
    @discardableResult
    func saveCreateCompositionDraft(
        privateSceneId: UUID?,
        name: String,
        subtitle: String,
        sourceSceneId: UUID?,
        composition: APIContentDTO.SceneComposition
    ) async throws -> APIContentDTO.PrivateSceneDetail {
        guard let remoteUserService, isRemoteAuthenticated else {
            throw ServiceError.unauthorized
        }
        let detail = try await remoteUserService.upsertCompositionDraft(
            privateSceneId: privateSceneId,
            name: name,
            subtitle: subtitle,
            sourceSceneId: sourceSceneId,
            composition: composition
        )
        if let listed = try? await remoteUserService.listPrivateScenes() {
            privateSceneSummaries = listed
        }
        if let source = sourceSceneId {
            privateSceneIdBySource[source] = detail.id
        }
        return detail
    }

    func refreshPrivateSceneSummaries() async {
        guard let remoteUserService, isRemoteAuthenticated else { return }
        if let listed = try? await remoteUserService.listPrivateScenes() {
            privateSceneSummaries = listed
        }
    }

    func fetchPrivateSceneDetail(id: UUID) async throws -> APIContentDTO.PrivateSceneDetail {
        guard let remoteUserService, isRemoteAuthenticated else {
            throw ServiceError.unauthorized
        }
        return try await remoteUserService.fetchPrivateScene(id: id)
    }

    /// Create editor uses the same cached official timeline as playback so an
    /// existing scene imports its authored clips and motion rather than a snapshot.
    func fetchSceneTimelineForCreate(
        sceneId: UUID
    ) async throws -> APIContentDTO.SceneTimeline {
        if let composition = store.loadCreatedComposition(sceneId: sceneId) {
            guard composition.schema != "scene_composition_v2" else {
                // CreateHub imports v2 through storedSceneCompositionForCreate.
                // Never silently flatten a v2 SourceGroup/clip document back to
                // the compatibility timeline if another caller reaches here.
                throw ServiceError.invalidState("v2 场景应通过 composition 导入")
            }
            let timeline = SceneCompositionTimelineMapper.timeline(
                from: composition,
                sceneId: sceneId
            )
            timelineCache[sceneId] = timeline
            return timeline
        }
        if let cached = timelineCache[sceneId] { return cached }
        let timeline = try await contentService.fetchTimeline(sceneId: sceneId)
        timelineCache[sceneId] = timeline
        return timeline
    }

    func storedSceneCompositionForCreate(
        sceneId: UUID
    ) -> APIContentDTO.SceneComposition? {
        store.loadCreatedComposition(sceneId: sceneId)
    }

    func fetchSceneForCreate(sceneId: UUID) async throws -> DreamScene {
        if let scene = scenes.first(where: { $0.id == sceneId }), !scene.soundSources.isEmpty {
            return scene
        }
        return try await contentService.fetchScene(id: sceneId)
    }

    func updateSourcePosition(id: UUID, position: SpatialPosition) {
        guard mixBoardSelection.isMine else { return }
        mutateCurrentSources { sources in
            if let i = sources.firstIndex(where: { $0.id == id }) {
                sources[i].position = position
            }
        }
        syncPersonalMixFromScene()
        pushSourceToPlayback(id: id)
        noteManualMixOverride(trackId: id)
    }

    private func mutateCurrentSources(_ body: (inout [SoundSource]) -> Void) {
        guard let idx = scenes.firstIndex(where: { $0.id == currentSceneId }) else { return }
        body(&scenes[idx].soundSources)
    }

    // MARK: - Sound assets

    /// Frontend: call before confirm-delete UI. Returns nil on failure.
    func fetchSoundDeleteImpact(id: UUID) async -> LibraryDeleteImpact? {
        try? await libraryService.deleteImpact(id: id)
    }

    func toggleSoundFavorite(id: UUID) {
        Task {
            if let updated = try? await libraryService.toggleFavorite(id: id) {
                if let i = soundAssets.firstIndex(where: { $0.id == id }) {
                    soundAssets[i] = updated
                }
            } else if let i = soundAssets.firstIndex(where: { $0.id == id }) {
                soundAssets[i].isFavorite.toggle()
            }
        }
    }

    func deleteSound(id: UUID) {
        soundAssets.removeAll { $0.id == id }
        if previewingSoundId == id { previewingSoundId = nil }
        Task { try? await libraryService.delete(id: id) }
    }

    func renameSound(id: UUID, name: String) {
        guard let i = soundAssets.firstIndex(where: { $0.id == id }) else { return }
        soundAssets[i].name = name
        Task { try? await libraryService.rename(id: id, name: name) }
    }

    func addSoundAsset(_ asset: SoundAsset) {
        soundAssets.insert(asset, at: 0)
        Task {
            try? await libraryService.upsert(asset)
        }
    }

    func toggleSoundPreview(id: UUID) {
        if previewingSoundId == id {
            previewingSoundId = nil
            playback.stopPreview()
            return
        }
        previewingSoundId = id
        if let i = soundAssets.firstIndex(where: { $0.id == id }) {
            soundAssets[i].lastUsedAt = Date()
            playback.preview(resourceName: soundAssets[i].previewResourceName)
        }
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if previewingSoundId == id {
                previewingSoundId = nil
            }
        }
    }

    // MARK: - Settings persistence

    func persistSettings() {
        guard !isApplyingRemoteSettings else { return }
        persistSettingsLocally()
        scheduleRemoteSettingsSync()
    }

    private func persistSettingsLocally() {
        defaults.set(reduceMotion, forKey: "dw.reduceMotion")
        defaults.set(autoPlayEnabled, forKey: "dw.autoPlay")
        defaults.set(backgroundPlayEnabled, forKey: "dw.bgPlay")
        defaults.set(lockScreenPlayEnabled, forKey: "dw.lockPlay")
        defaults.set(animationIntensity, forKey: "dw.animIntensity")
        defaults.set(darkModeForced, forKey: "dw.darkMode")
        defaults.set(audioQuality, forKey: "dw.audioQuality")
        defaults.set(notificationsEnabled, forKey: "dw.notifications")
        defaults.set(nickname, forKey: "dw.nickname")
        defaults.set(isAppleSignedIn, forKey: "dw.appleSignIn")
        defaults.set(isMember, forKey: "dw.member")
    }

    /// Debounce slider / multi-toggle bursts so the last snapshot wins on the server.
    private func scheduleRemoteSettingsSync() {
        guard contentBackendMode == .remote, isRemoteAuthenticated, remoteUserService != nil else { return }
        remoteSettingsSyncTask?.cancel()
        remoteSettingsSyncTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard let self, !Task.isCancelled else { return }
            await self.pushSettingsToRemote()
        }
    }

    /// Call when leaving foreground so a pending debounced PUT is not lost on kill.
    func flushPendingSettingsSync() async {
        guard !isApplyingRemoteSettings else { return }
        remoteSettingsSyncTask?.cancel()
        remoteSettingsSyncTask = nil
        persistSettingsLocally()
        await pushSettingsToRemote()
    }

    private func pushSettingsToRemote() async {
        guard contentBackendMode == .remote,
              isRemoteAuthenticated,
              let remoteUserService,
              !isApplyingRemoteSettings else { return }
        do {
            _ = try await remoteUserService.updateSettings(
                APIContentDTO.SettingsUpdate(
                    reduce_motion: reduceMotion,
                    auto_play_enabled: autoPlayEnabled,
                    background_play_enabled: backgroundPlayEnabled,
                    lock_screen_play_enabled: lockScreenPlayEnabled,
                    animation_intensity: animationIntensity,
                    dark_mode_forced: darkModeForced,
                    audio_quality: audioQuality,
                    notifications_enabled: notificationsEnabled
                )
            )
        } catch {
            lastServiceMessage = "设置同步失败：\(error.localizedDescription)"
        }
    }
}
