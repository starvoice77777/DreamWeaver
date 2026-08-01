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
    let libraryService: LocalUserLibraryService
    let seedPipeline: LocalSeedPipelineService
    let analyticsService: LocalAnalyticsService
    let playback: LocalPlaybackService
    /// Frontend-visible: which content backend this process started with.
    let contentBackendMode: ServiceBackendMode

    private let defaults = UserDefaults.standard
    private let store = DemoPersistenceStore.shared
    private var hideControlsTask: Task<Void, Never>?
    private var hideTitleTask: Task<Void, Never>?
    private var hideMixPaletteTask: Task<Void, Never>?
    private var idleReturnToNowTask: Task<Void, Never>?
    private var sessionStartedAt: Date?

    convenience init() {
        let mode = ServiceBackendConfig.mode
        let content: ContentService
        switch mode {
        case .remote:
            content = RemoteContentService(client: .shared)
        case .local:
            content = LocalContentService()
        }
        self.init(
            contentService: content,
            libraryService: LocalUserLibraryService(),
            seedPipeline: LocalSeedPipelineService(),
            analyticsService: LocalAnalyticsService(),
            playback: LocalPlaybackService(),
            contentBackendMode: mode
        )
    }

    init(
        contentService: ContentService,
        libraryService: LocalUserLibraryService,
        seedPipeline: LocalSeedPipelineService,
        analyticsService: LocalAnalyticsService,
        playback: LocalPlaybackService,
        contentBackendMode: ServiceBackendMode = .local
    ) {
        self.contentService = contentService
        self.libraryService = libraryService
        self.seedPipeline = seedPipeline
        self.analyticsService = analyticsService
        self.playback = playback
        self.contentBackendMode = contentBackendMode

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

    // MARK: - Bootstrap

    func bootstrap() async {
        do {
            if contentBackendMode == .remote {
                _ = try await contentService.loadBootstrap()
            }

            let loadedScenes = try await contentService.fetchScenes()
            scenes = loadedScenes
            soundAssets = try await libraryService.fetchAssets()
            usageRecord = try await analyticsService.summary()
            mixPresets = try await contentService.fetchMixPresets(sceneStyle: nil)

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

            reloadPlayback(autoPlay: autoPlayEnabled)
        } catch {
            lastServiceMessage = error.localizedDescription
        }
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
        withAnimation(.easeInOut(duration: reduceMotion ? 0.2 : 1.0)) {
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
        do {
            try playback.load(scene: currentScene, sources: currentScene.soundSources.filter(\.isEnabled))
            playbackProgress = playback.progress
            if autoPlay {
                playback.play()
                isPlaying = playback.isPlaying
            } else {
                isPlaying = false
            }
            if let message = playback.lastErrorMessage {
                lastServiceMessage = message
            }
        } catch {
            // Keep UI in sync with a stopped engine when load/session setup fails.
            isPlaying = false
            lastServiceMessage = error.localizedDescription
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
            pan: LocalPlaybackService.pan(from: source.position),
            enabled: source.isEnabled
        )
        playbackProgress = playback.progress
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
        noteUserActivity()
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

    // MARK: - Idle return to「此刻」

    /// Call on any user activity while away from the Now tab.
    func noteUserActivity() {
        guard selectedTab != .now else {
            idleReturnToNowTask?.cancel()
            return
        }
        scheduleReturnToNowIfNeeded()
    }

    func cancelReturnToNow() {
        idleReturnToNowTask?.cancel()
        idleReturnToNowTask = nil
    }

    func scheduleReturnToNowIfNeeded() {
        idleReturnToNowTask?.cancel()
        guard selectedTab != .now else { return }
        idleReturnToNowTask = Task {
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            guard !Task.isCancelled, selectedTab != .now else { return }
            withAnimation(.easeInOut(duration: DreamTheme.chromeVisibilityDuration)) {
                selectedTab = .now
            }
            revealControls()
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

            currentSceneId = sceneId
            defaults.set(sceneId.uuidString, forKey: "dw.lastSceneId")
            playbackProgress = 0.08
            mixBoardSelection = .mine
            if let personal = personalMixByScene[sceneId] {
                mutateCurrentSources { $0 = personal }
            } else {
                personalMixByScene[sceneId] = currentScene.soundSources
            }

            withAnimation(.easeInOut(duration: reduceMotion ? 0.15 : 0.45)) {
                selectedTab = .now
            }
            cancelReturnToNow()

            // `isPlaying` is set only after load/play succeeds inside reloadPlayback.
            reloadPlayback(autoPlay: true)
            sessionStartedAt = Date()

            try? await Task.sleep(nanoseconds: UInt64(hold * 1_000_000_000))

            withAnimation(.easeInOut(duration: fadeIn)) {
                isTransitioningScene = false
            }

            try? await Task.sleep(nanoseconds: UInt64((fadeIn * 0.35) * 1_000_000_000))
            showSceneTitleTemporarily()
            revealControls()
        }
    }

    func toggleFavorite(sceneId: UUID) {
        guard let idx = scenes.firstIndex(where: { $0.id == sceneId }) else { return }
        scenes[idx].isFavorite.toggle()
        try? contentService.persistSceneOverlay(scenes: scenes)
        bumpInteraction()
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
        markMixInteraction()
    }

    func updateSourcePlacement(id: UUID, position: SpatialPosition) {
        guard mixBoardSelection.isMine else { return }
        let volume = Self.volume(fromRadius: position.radius)
        mutateCurrentSources { sources in
            if let i = sources.firstIndex(where: { $0.id == id }) {
                sources[i].position = position
                sources[i].volume = volume
                sources[i].isEnabled = true
            }
        }
        syncPersonalMixFromScene()
        pushSourceToPlayback(id: id)
        markMixInteraction()
        Task { try? await analyticsService.record(.mixEdited(sceneId: currentSceneId)) }
    }

    static func volume(fromRadius radius: Double) -> Double {
        let normalized = (radius - 0.22) / (0.95 - 0.22)
        return min(max(1.0 - normalized, 0.12), 1.0)
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
        markMixInteraction()
    }

    func removeSource(id: UUID) {
        guard mixBoardSelection.isMine else { return }
        mutateCurrentSources { sources in
            sources.removeAll { $0.id == id }
        }
        syncPersonalMixFromScene()
        pushSpatialToPlayback()
        markMixInteraction()
    }

    func addSource(_ source: SoundSource) {
        guard mixBoardSelection.isMine else { return }
        mutateCurrentSources { sources in
            sources.append(source)
        }
        syncPersonalMixFromScene()
        pushSpatialToPlayback()
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
    }

    private func mutateCurrentSources(_ body: (inout [SoundSource]) -> Void) {
        guard let idx = scenes.firstIndex(where: { $0.id == currentSceneId }) else { return }
        body(&scenes[idx].soundSources)
    }

    // MARK: - Sound assets

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
}
