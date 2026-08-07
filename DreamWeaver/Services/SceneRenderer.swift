import Combine
import Foundation

nonisolated struct RendererSourceState: Identifiable, Equatable, Sendable {
    let id: UUID
    var position: SpatialPosition
    var radialGain: Double
    var automationGain: Double
    var isActive: Bool
    var activeClipIDs: Set<UUID>
}

nonisolated struct RendererState: Equatable, Sendable {
    var time: Double
    var isPlaying: Bool
    var sourceGroups: [RendererSourceState]
    var activeClipIDs: Set<UUID>

    static let empty = RendererState(
        time: 0,
        isPlaying: false,
        sourceGroups: [],
        activeClipIDs: []
    )
}

/// Shared monotonic renderer clock. It evaluates both UI positions and audio
/// parameters from the same plan, eliminating independent Create/Now timers.
@MainActor
final class SceneRenderer: ObservableObject {
    @Published private(set) var state: RendererState = .empty

    var onStateChange: ((RendererState) -> Void)?

    private(set) var plan: SceneRenderPlan?
    private var clockTask: Task<Void, Never>?
    private var startedUptime: TimeInterval?
    private var startedPlanTime: Double = 0
    private var manualPositions: [UUID: SpatialPosition] = [:]
    private let frameNanoseconds: UInt64 = 16_666_667

    func load(_ plan: SceneRenderPlan, at time: Double = 0) {
        stopClock()
        self.plan = plan
        manualPositions = [:]
        publish(time: clampedTime(time), isPlaying: false)
    }

    func play() {
        guard plan != nil, !state.isPlaying else { return }
        if let plan, state.time >= plan.durationSeconds {
            publish(time: 0, isPlaying: false)
        }
        startedPlanTime = state.time
        startedUptime = ProcessInfo.processInfo.systemUptime
        publish(time: state.time, isPlaying: true)
        startClock()
    }

    func pause() {
        guard state.isPlaying else { return }
        publish(time: currentMonotonicTime(), isPlaying: false)
        stopClock()
    }

    func stop() {
        stopClock()
        startedPlanTime = 0
        startedUptime = nil
        publish(time: 0, isPlaying: false)
    }

    func seek(to time: Double) {
        let wasPlaying = state.isPlaying
        startedPlanTime = clampedTime(time)
        startedUptime = wasPlaying ? ProcessInfo.processInfo.systemUptime : nil
        publish(time: startedPlanTime, isPlaying: wasPlaying)
    }

    func setManualPosition(_ position: SpatialPosition, for sourceGroupID: UUID) {
        manualPositions[sourceGroupID] = position
        publish(time: state.time, isPlaying: state.isPlaying)
    }

    func clearManualPosition(for sourceGroupID: UUID) {
        manualPositions[sourceGroupID] = nil
        publish(time: state.time, isPlaying: state.isPlaying)
    }

    private func startClock() {
        clockTask?.cancel()
        clockTask = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled, self.state.isPlaying {
                do {
                    try await Task.sleep(nanoseconds: self.frameNanoseconds)
                } catch {
                    return
                }
                let time = self.currentMonotonicTime()
                if let plan = self.plan, time >= plan.durationSeconds {
                    self.publish(time: plan.durationSeconds, isPlaying: false)
                    self.stopClock()
                    return
                }
                self.publish(time: time, isPlaying: true)
            }
        }
    }

    private func stopClock() {
        clockTask?.cancel()
        clockTask = nil
        startedUptime = nil
    }

    private func currentMonotonicTime() -> Double {
        guard let startedUptime else { return state.time }
        return clampedTime(
            startedPlanTime + ProcessInfo.processInfo.systemUptime - startedUptime
        )
    }

    private func clampedTime(_ time: Double) -> Double {
        min(max(time, 0), plan?.durationSeconds ?? max(time, 0))
    }

    private func publish(time: Double, isPlaying: Bool) {
        guard let plan else {
            state = .empty
            onStateChange?(state)
            return
        }
        let activeClips = plan.clips.filter {
            time >= $0.startSeconds && time < $0.endSeconds
        }
        let activeIDs = Set(activeClips.map(\.id))
        let clipsByGroup = Dictionary(grouping: activeClips, by: \.sourceGroupID)
        let sourceStates = plan.sourceGroups.map { group in
            let position = manualPositions[group.id] ?? SpatialTrajectoryEvaluator.position(
                at: time,
                keyframes: group.positionKeyframes,
                defaultPosition: group.defaultPosition
            )
            let groupClips = Set((clipsByGroup[group.id] ?? []).map(\.id))
            let automation = automationGain(for: group.id, at: time, plan: plan)
            return RendererSourceState(
                id: group.id,
                position: position,
                radialGain: RadialGainCurve.gain(forRadius: position.radius),
                automationGain: automation,
                isActive: !groupClips.isEmpty,
                activeClipIDs: groupClips
            )
        }
        let next = RendererState(
            time: time,
            isPlaying: isPlaying,
            sourceGroups: sourceStates,
            activeClipIDs: activeIDs
        )
        state = next
        onStateChange?(next)
    }

    private func automationGain(
        for groupID: UUID,
        at time: Double,
        plan: SceneRenderPlan
    ) -> Double {
        plan.automationCurves.reduce(1) { result, curve in
            guard curve.target == .sourceGroup(groupID) else { return result }
            return result * SpatialTrajectoryEvaluator.automationValue(
                at: time,
                keyframes: curve.keyframes
            )
        }
    }
}
