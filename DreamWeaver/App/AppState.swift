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
    /// Elapsed fraction 0...1 for countdown timer chips.
    @Published private(set) var timerElapsedProgress: Double = 0
    @Published var soundAssets: [SoundAsset]
    @Published var usageRecord: UsageRecord
    @Published var savedMixes: [SavedMix] = []
    @Published var mixPresets: [MixPreset]
    @Published var mixBoardSelection: MixBoardSelection = .mine
    private var personalMixByScene: [UUID: [SoundSource]] = [:]

    @Published var showLaunch = true
    @Published var controlsVisible = true
    @Published var showSeedFlow = false
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
    /// Local or remote seed pipeline (`RemoteSeedPipelineService` when content backend is remote).
    let seedPipeline: SeedPipelineService
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
    private var hideControlsTask: Task<Void, Never>?
    private var hideTitleTask: Task<Void, Never>?
    private var hideMixPaletteTask: Task<Void, Never>?
    private var sessionStartedAt: Date?
    /// Maps official scene id → private scene id when home/save links them.
    private var privateSceneIdBySource: [UUID: UUID] = [:]
    /// Warm timelines for swipe targets so playback reload skips a network/disk round-trip.
    private var timelineCache: [UUID: APIContentDTO.SceneTimeline] = [:]
    private var swipePrefetchTasks: [UUID: Task<Void, Never>] = [:]
    /// Prevents Settings `onChange` → `persistSettings` from racing while hydrating remote prefs.
    private var isApplyingRemoteSettings = false
    private var remoteSettingsSyncTask: Task<Void, Never>?

    convenience init() {
        let mode = ServiceBackendConfig.mode
        let content: ContentService
        let auth: RemoteAuthService?
        let remoteUser: RemoteUserService?
        let library: UserLibraryService
        let remoteLibrary: RemoteUserLibraryService?
        let seed: SeedPipelineService
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
            seed = RemoteSeedPipelineService(client: client, library: remoteLib)
            analytics = RemoteAnalyticsService(client: client)
        case .local:
            content = LocalContentService()
            auth = nil
            remoteUser = nil
            library = LocalUserLibraryService()
            remoteLibrary = nil
            seed = LocalSeedPipelineService()
            analytics = LocalAnalyticsService()
        }
        self.init(
            contentService: content,
            libraryService: library,
            seedPipeline: seed,
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
        seedPipeline: SeedPipelineService,
        analyticsService: AnalyticsService,
        playback: LocalPlaybackService,
        contentBackendMode: ServiceBackendMode = .local,
        authService: RemoteAuthService? = nil,
        remoteUserService: RemoteUserService? = nil,
        remoteLibraryService: RemoteUserLibraryService? = nil
    ) {
        self.contentService = contentService
        self.libraryService = libraryService
        self.seedPipeline = seedPipeline
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

        scenes = MockDataService.makeScenes()
        soundAssets = MockDataService.makeSoundAssets()
        usageRecord = MockDataService.makeUsageRecord()
        mixPresets = MockDataService.makeMixPresets()
        mixBoardSelection = .mine
        currentSceneId = DemoIDs.hairCareScene

        if let mixStore = store.loadPersonalMix() {
            for (key, value) in mixStore.byScene {
                if let id = UUID(uuidString: key) {
                    personalMixByScene[id] = value
                }
            }
        }

        Task { await self.bootstrap() }
    }

    var currentScene: DreamScene {
        scenes.first(where: { $0.id == currentSceneId }) ?? scenes[0]
    }

    var currentSceneIndex: Int {
        scenes.firstIndex(where: { $0.id == currentSceneId }) ?? 0
    }

    /// Official / community presets that belong to the current scene (for MixPresetBrowser).
    var mixPresetsForCurrentScene: [MixPreset] {
        let styleKey = currentScene.visualStyle.rawValue
        let sceneId = currentSceneId
        return mixPresets.filter { preset in
            if let sid = preset.sceneId { return sid == sceneId }
            if let hint = preset.styleHint, !hint.isEmpty { return hint == styleKey }
            if !preset.subtitle.isEmpty, preset.subtitle == styleKey { return true }
            return legacyPresetMatchesCurrentScene(preset)
        }
    }

    private func legacyPresetMatchesCurrentScene(_ preset: MixPreset) -> Bool {
        switch currentScene.visualStyle {
        case .hairCare:
            return preset.id == DemoIDs.presetHairCare
        case .rainEaves:
            return preset.id == DemoIDs.presetRainFine || preset.id == DemoIDs.presetBreathOnly
        case .fireflies:
            return preset.id == DemoIDs.presetForestGlow
        case .mistTide:
            return preset.id == DemoIDs.presetMistTide
        case .fireplaceWhisper:
            return preset.id == DemoIDs.presetFireplace
        case .starRiver:
            return preset.id == DemoIDs.presetStarRiver
        case .cloudBreath:
            return preset.id == DemoIDs.presetBreathOnly
        default:
            return false
        }
    }

    // MARK: - Bootstrap

    func bootstrap() async {
        do {
            if contentBackendMode == .remote {
                _ = try await contentService.loadBootstrap()
            }

            let loadedScenes = try await contentService.fetchScenes()
            scenes = loadedScenes
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
                lastServiceMessage = "混音预设加载失败：\(error.localizedDescription)"
            }

            if let lastIdString = defaults.string(forKey: "dw.lastSceneId"),
               let lastId = UUID(uuidString: lastIdString),
               loadedScenes.contains(where: { $0.id == lastId }) {
                currentSceneId = lastId
            } else if loadedScenes.contains(where: { $0.id == DemoIDs.hairCareScene }) {
                currentSceneId = DemoIDs.hairCareScene
            } else if let defaultScene = loadedScenes.first(where: { $0.name == MockDataService.defaultSceneName }) {
                currentSceneId = defaultScene.id
            } else if let first = loadedScenes.first {
                currentSceneId = first.id
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
        if let sceneId = settings.default_scene_id,
           scenes.contains(where: { $0.id == sceneId }) {
            currentSceneId = sceneId
        }
        // Mirror hydrated remote prefs into UserDefaults without a remote PUT loop.
        persistSettingsLocally()
    }

    /// Restores fixture data for filming. Call before each take.
    func resetDemoState() {
        store.resetAllDemoKeys()
        scenes = MockDataService.makeScenes()
        soundAssets = MockDataService.makeSoundAssets()
        usageRecord = MockDataService.makeUsageRecord()
        mixPresets = MockDataService.makeMixPresets()
        personalMixByScene = [:]
        savedMixes = []
        currentSceneId = DemoIDs.hairCareScene
        defaults.set(DemoIDs.hairCareScene.uuidString, forKey: "dw.lastSceneId")
        timerOption = .autoStop
        timerElapsedProgress = 0
        playback.cancelSleepTimer()
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

    func finishLaunch() {
        // Overlay is already fully transparent; drop it without a second fade of「此刻」.
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            showLaunch = false
        }
        showSceneTitleTemporarily()
        scheduleHideControls()
        if autoPlayEnabled {
            playback.play()
            isPlaying = playback.isPlaying
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
        }
        bumpInteraction()
    }

    func setTimerOption(_ option: TimerOption) {
        timerOption = option
        timerElapsedProgress = 0
        playback.cancelSleepTimer()

        guard option.showsCountdownFill || option == .demoAccelerated else { return }

        playback.startSleepTimer(
            option: option,
            onTick: { [weak self] progress in
                self?.timerElapsedProgress = progress
            },
            onFinished: { [weak self] in
                guard let self else { return }
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
            let timeline: APIContentDTO.SceneTimeline?
            if let cached = self.timelineCache[sceneId] {
                timeline = cached
            } else if let fetched = try? await self.contentService.fetchTimeline(sceneId: sceneId) {
                self.timelineCache[sceneId] = fetched
                timeline = fetched
            } else {
                timeline = nil
            }
            do {
                try self.playback.load(scene: scene, sources: sources, timeline: timeline)
                self.playbackProgress = self.playback.progress
                if autoPlay {
                    self.playback.play()
                    self.isPlaying = self.playback.isPlaying
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
            volume: source.volume,
            position: source.position,
            enabled: source.isEnabled
        )
        playbackProgress = playback.progress
    }

    /// Frontend/backend: user mix edit exits timeline automation for this track only.
    private func noteManualMixOverride(trackId: UUID) {
        playback.markManualOverride(trackId: trackId)
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
        if controlsVisible {
            scheduleHideControls()
        } else {
            hideControlsTask?.cancel()
            hideMixPaletteTask?.cancel()
        }
    }

    func revealControls() {
        setControlsVisible(true)
        if showMixPalette {
            scheduleHideMixPalette()
        } else {
            scheduleHideControls()
        }
    }

    func scheduleHideControls() {
        hideControlsTask?.cancel()
        hideControlsTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled, !showMixPalette, !userIsInteracting else { return }
            setControlsVisible(false)
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
            } else {
                scheduleHideControls()
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
        hideControlsTask?.cancel()
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
        scheduleHideControls()
    }

    func scheduleHideMixPalette() {
        hideMixPaletteTask?.cancel()
        hideControlsTask?.cancel()
        guard !isMixDragging else { return }
        hideMixPaletteTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled, showMixPalette, !isMixDragging, !userIsInteracting else { return }
            withAnimation(DreamTheme.chromeVisibilityAnimation) {
                showMixPalette = false
            }
            scheduleHideControls()
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
        } else {
            scheduleHideControls()
        }
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            userIsInteracting = false
            if showMixPalette {
                if !isMixDragging {
                    scheduleHideMixPalette()
                }
            } else {
                scheduleHideControls()
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
        scheduleHideControls()
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
        defaults.set(sceneId.uuidString, forKey: "dw.lastSceneId")
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

    func updateSourceVolume(id: UUID, volume: Double) {
        guard mixBoardSelection.isMine else { return }
        mutateCurrentSources { sources in
            if let i = sources.firstIndex(where: { $0.id == id }) {
                sources[i].volume = volume
            }
        }
        syncPersonalMixFromScene()
        pushSourceToPlayback(id: id)
        noteManualMixOverride(trackId: id)
        markMixInteraction()
    }

    func updateSourcePlacement(id: UUID, position: SpatialPosition) {
        guard mixBoardSelection.isMine else { return }
        // Distance attenuation comes from AVAudioEnvironmentNode; keep mix gain as-is.
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

    /// Default mix gain for newly dropped sources (distance is spatialized separately).
    static func volume(fromRadius _: Double) -> Double {
        SpatialMixMapping.defaultMixGain
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
        if let original = MockDataService.makeScenes().first(where: { $0.name == currentScene.name }) {
            mutateCurrentSources { $0 = duplicatedSources(original.soundSources) }
            syncPersonalMixFromScene()
            pushSpatialToPlayback()
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
                pushSpatialToPlayback()
            }
        }
        mixBoardSelection = .mine
        markMixInteraction()
    }

    func selectMixPreset(_ preset: MixPreset) {
        if mixBoardSelection.isMine {
            syncPersonalMixFromScene()
        }
        let fresh = duplicatedSources(preset.sources, forceEnabled: true)
        withAnimation(.easeInOut(duration: 0.35)) {
            mutateCurrentSources { $0 = fresh }
            mixBoardSelection = .preset(preset.id)
        }
        pushSpatialToPlayback()
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

    private func duplicatedSources(_ sources: [SoundSource], forceEnabled: Bool = false) -> [SoundSource] {
        sources.map {
            SoundSource(
                id: UUID(),
                name: $0.name,
                symbolName: $0.symbolName,
                isEnabled: forceEnabled ? true : $0.isEnabled,
                volume: $0.volume,
                position: $0.position,
                assetId: $0.assetId,
                resourceName: $0.resourceName,
                layer: $0.layer
            )
        }
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
            try? await analyticsService.record(.seedCreated(assetId: asset.id))
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
        defaults.set(currentSceneId.uuidString, forKey: "dw.lastSceneId")
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
                    notifications_enabled: notificationsEnabled,
                    default_scene_id: currentSceneId
                )
            )
        } catch {
            lastServiceMessage = "设置同步失败：\(error.localizedDescription)"
        }
    }
}
