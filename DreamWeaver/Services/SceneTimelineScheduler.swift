import Foundation

/// Expands a versioned scene timeline into wall-clock events and advances on elapsed time.
/// Unknown action types are ignored by the executor (not by this planner).
@MainActor
final class SceneTimelineScheduler {
    struct FireEvent: Hashable {
        let fireAt: TimeInterval
        let cueId: UUID
        let actions: [APIContentDTO.CueAction]
    }

    private(set) var events: [FireEvent] = []
    private var nextIndex = 0
    private var clockStartedAt: Date?
    private var pausedElapsed: TimeInterval = 0
    private var tickTimer: Timer?
    private var manualOverrideTrackIds: Set<UUID> = []

    private var onFire: (([APIContentDTO.CueAction]) -> Void)?

    var elapsedSeconds: TimeInterval {
        if let started = clockStartedAt {
            return pausedElapsed + Date().timeIntervalSince(started)
        }
        return pausedElapsed
    }

    func configure(
        timeline: APIContentDTO.SceneTimeline?,
        overrides: Set<UUID> = [],
        onFire: @escaping ([APIContentDTO.CueAction]) -> Void
    ) {
        stop()
        self.onFire = onFire
        manualOverrideTrackIds = overrides.union(Set(timeline?.manual_override_track_ids ?? []))
        events = Self.expand(timeline: timeline).sorted { $0.fireAt < $1.fireAt }
        nextIndex = 0
        pausedElapsed = 0
        clockStartedAt = nil
    }

    func markManualOverride(trackId: UUID) {
        manualOverrideTrackIds.insert(trackId)
    }

    func clearManualOverrides() {
        manualOverrideTrackIds.removeAll()
    }

    func start() {
        guard !events.isEmpty else { return }
        if clockStartedAt != nil { return }
        if pausedElapsed > 0 || nextIndex > 0 {
            resume()
            return
        }
        clockStartedAt = Date()
        beginTicking()
        tick()
    }

    func pause() {
        pausedElapsed = elapsedSeconds
        clockStartedAt = nil
        tickTimer?.invalidate()
        tickTimer = nil
    }

    func resume() {
        guard clockStartedAt == nil else { return }
        guard nextIndex < events.count else { return }
        clockStartedAt = Date()
        beginTicking()
        tick()
    }

    func stop() {
        tickTimer?.invalidate()
        tickTimer = nil
        clockStartedAt = nil
        pausedElapsed = 0
        nextIndex = 0
    }

    private func beginTicking() {
        tickTimer?.invalidate()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    private func tick() {
        let now = elapsedSeconds
        while nextIndex < events.count, events[nextIndex].fireAt <= now {
            let event = events[nextIndex]
            nextIndex += 1
            let actions = event.actions.filter { action in
                guard let trackId = action.track_id else { return true }
                return !manualOverrideTrackIds.contains(trackId)
            }
            if !actions.isEmpty {
                onFire?(actions)
            }
        }
        if nextIndex >= events.count {
            tickTimer?.invalidate()
            tickTimer = nil
        }
    }

    /// Flatten cues (including repeats / progress anchors) into one-shot fire times.
    static func expand(timeline: APIContentDTO.SceneTimeline?) -> [FireEvent] {
        guard let timeline else { return [] }
        let duration = TimeInterval(timeline.duration_hint_seconds ?? 2700)
        var result: [FireEvent] = []

        for cue in timeline.cues {
            let actions = cue.actions
            guard !actions.isEmpty else { continue }

            if let progress = cue.progress {
                let at = max(0, min(1, progress)) * duration
                result.append(FireEvent(fireAt: at, cueId: cue.id, actions: actions))
                continue
            }

            guard let at = cue.at_seconds else { continue }
            let start = max(0, at)

            if let period = cue.repeat_every_seconds, period > 0 {
                let until = cue.until_seconds ?? duration
                var t = start
                var guardCount = 0
                while t <= until + 0.001, guardCount < 500 {
                    result.append(FireEvent(fireAt: t, cueId: cue.id, actions: actions))
                    t += period
                    guardCount += 1
                }
            } else {
                result.append(FireEvent(fireAt: start, cueId: cue.id, actions: actions))
            }
        }
        return result
    }
}
