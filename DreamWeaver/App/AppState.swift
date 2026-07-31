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
    /// Elapsed fraction 0...1 for countdown timer chips (10 / 30 / 60 min).
    @Published private(set) var timerElapsedProgress: Double = 0
    @Published var soundAssets: [SoundAsset]
    @Published var usageRecord: UsageRecord
    @Published var savedMixes: [SavedMix] = []
    @Published var mixPresets: [MixPreset]
    /// 「我的」可编辑；选中官方预设时仅试听，不可改，也不覆盖「我的」。
    @Published var mixBoardSelection: MixBoardSelection = .mine
    /// Per-scene personal mix snapshots. Preset switches never mutate these.
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

    let isFirstLaunch: Bool

    private let defaults = UserDefaults.standard
    private var progressTimer: Timer?
    private var sleepTimerTick: Timer?
    private var sleepTimerStartedAt: Date?
    private var sleepTimerDuration: TimeInterval = 0
    private var hideControlsTask: Task<Void, Never>?
    private var hideTitleTask: Task<Void, Never>?
    private var hideMixPaletteTask: Task<Void, Never>?
    private var idleReturnToNowTask: Task<Void, Never>?

    init() {
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

        let allScenes = MockDataService.makeScenes()
        scenes = allScenes
        soundAssets = MockDataService.makeSoundAssets()
        usageRecord = MockDataService.makeUsageRecord()
        mixPresets = MockDataService.makeMixPresets()
        mixBoardSelection = .mine

        if let lastIdString = defaults.string(forKey: "dw.lastSceneId"),
           let lastId = UUID(uuidString: lastIdString),
           allScenes.contains(where: { $0.id == lastId }) {
            currentSceneId = lastId
        } else if let defaultScene = allScenes.first(where: { $0.name == MockDataService.defaultSceneName }) {
            currentSceneId = defaultScene.id
        } else {
            currentSceneId = allScenes[0].id
        }

        personalMixByScene[currentSceneId] = allScenes.first(where: { $0.id == currentSceneId })?.soundSources ?? []

        isPlaying = autoPlayEnabled
        startProgressSimulation()
    }

    var currentScene: DreamScene {
        scenes.first(where: { $0.id == currentSceneId }) ?? scenes[0]
    }

    var currentSceneIndex: Int {
        scenes.firstIndex(where: { $0.id == currentSceneId }) ?? 0
    }

    // MARK: - Launch

    func finishLaunch() {
        withAnimation(.easeInOut(duration: reduceMotion ? 0.2 : 1.0)) {
            showLaunch = false
        }
        showSceneTitleTemporarily()
        scheduleHideControls()
        if autoPlayEnabled {
            isPlaying = true
        }
    }

    // MARK: - Playback

    func togglePlayback() {
        isPlaying.toggle()
        if isPlaying {
            startProgressSimulation()
        }
        bumpInteraction()
    }

    func setTimerOption(_ option: TimerOption) {
        timerOption = option
        sleepTimerTick?.invalidate()
        sleepTimerTick = nil
        timerElapsedProgress = 0
        sleepTimerStartedAt = nil
        sleepTimerDuration = 0

        guard option.showsCountdownFill, let minutes = option.minutes else { return }

        sleepTimerDuration = TimeInterval(minutes * 60)
        sleepTimerStartedAt = Date()
        sleepTimerTick = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tickSleepTimer()
            }
        }
    }

    private func tickSleepTimer() {
        guard let started = sleepTimerStartedAt, sleepTimerDuration > 0 else { return }
        let elapsed = Date().timeIntervalSince(started)
        timerElapsedProgress = min(max(elapsed / sleepTimerDuration, 0), 1)
        if timerElapsedProgress >= 1 {
            sleepTimerTick?.invalidate()
            sleepTimerTick = nil
            isPlaying = false
        }
    }

    func startProgressSimulation() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, self.isPlaying else { return }
                self.playbackProgress = min(self.playbackProgress + 0.0035, 0.97)
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

        // Keep the world under a soft curtain while we land on「此刻」.
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
            isPlaying = true
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
        bumpInteraction()
    }

    /// 「常用」由聆听次数决定，始终只保留前 6 个场景。
    func recordListening(sceneId: UUID) {
        guard let idx = scenes.firstIndex(where: { $0.id == sceneId }) else { return }
        scenes[idx].listenCount += 1
        refreshFrequentScenes()
        usageRecord.lastUsedAt = Date()
    }

    func refreshFrequentScenes() {
        scenes = MockDataService.markTopFrequentScenes(scenes)
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
        markMixInteraction()
    }

    /// Updates spatial position and derives volume from distance to center (near = louder).
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
        markMixInteraction()
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
        markMixInteraction()
    }

    func removeSource(id: UUID) {
        guard mixBoardSelection.isMine else { return }
        let enabled = currentScene.soundSources.filter(\.isEnabled)
        // Keep at least one active source on the disk.
        if enabled.count <= 1, enabled.contains(where: { $0.id == id }) {
            return
        }
        mutateCurrentSources { sources in
            sources.removeAll { $0.id == id }
        }
        syncPersonalMixFromScene()
        markMixInteraction()
    }

    func addSource(_ source: SoundSource) {
        guard mixBoardSelection.isMine else { return }
        mutateCurrentSources { sources in
            sources.append(source)
        }
        syncPersonalMixFromScene()
        markMixInteraction()
    }

    func restoreDefaultMix() {
        guard mixBoardSelection.isMine else { return }
        if let original = MockDataService.makeScenes().first(where: { $0.name == currentScene.name }) {
            mutateCurrentSources { $0 = duplicatedSources(original.soundSources) }
            syncPersonalMixFromScene()
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
    }

    private func duplicatedSources(_ sources: [SoundSource], forceEnabled: Bool = false) -> [SoundSource] {
        sources.map {
            SoundSource(
                name: $0.name,
                symbolName: $0.symbolName,
                isEnabled: forceEnabled ? true : $0.isEnabled,
                volume: $0.volume,
                position: $0.position,
                assetId: $0.assetId
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
    }

    private func mutateCurrentSources(_ body: (inout [SoundSource]) -> Void) {
        guard let idx = scenes.firstIndex(where: { $0.id == currentSceneId }) else { return }
        body(&scenes[idx].soundSources)
    }

    // MARK: - Sound assets

    func toggleSoundFavorite(id: UUID) {
        guard let i = soundAssets.firstIndex(where: { $0.id == id }) else { return }
        soundAssets[i].isFavorite.toggle()
    }

    func deleteSound(id: UUID) {
        soundAssets.removeAll { $0.id == id }
        if previewingSoundId == id { previewingSoundId = nil }
    }

    func renameSound(id: UUID, name: String) {
        guard let i = soundAssets.firstIndex(where: { $0.id == id }) else { return }
        soundAssets[i].name = name
    }

    func addSoundAsset(_ asset: SoundAsset) {
        soundAssets.insert(asset, at: 0)
    }

    func toggleSoundPreview(id: UUID) {
        if previewingSoundId == id {
            previewingSoundId = nil
        } else {
            previewingSoundId = id
            if let i = soundAssets.firstIndex(where: { $0.id == id }) {
                soundAssets[i].lastUsedAt = Date()
            }
            Task {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                if previewingSoundId == id {
                    previewingSoundId = nil
                }
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
