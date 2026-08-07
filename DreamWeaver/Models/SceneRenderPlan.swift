import Foundation

nonisolated enum SceneAutomationTarget: Codable, Equatable, Sendable {
    case sourceGroup(UUID)
    case clip(UUID)
}

nonisolated enum SceneAutomationParameter: String, Codable, Sendable {
    case envelope
    case duck
}

nonisolated struct SceneAutomationKeyframe: Codable, Equatable, Sendable {
    var time: Double
    var value: Double
    var interpolation: SceneInterpolationMode
}

/// Temporary gain automation only. Steady-state source loudness belongs to the
/// source group's radius and is never duplicated here.
nonisolated struct SceneAutomationCurve: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var target: SceneAutomationTarget
    var parameter: SceneAutomationParameter
    var keyframes: [SceneAutomationKeyframe]
    var priority: Int
}

nonisolated enum SceneRenderEventAction: String, Codable, Sendable {
    case startClip = "start_clip"
    case stopClip = "stop_clip"
}

nonisolated struct SceneRenderEvent: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var time: Double
    var action: SceneRenderEventAction
    var clipID: UUID
}

/// Read-only executable scene representation shared by the Now player and the
/// Create preview. Source data is compiled once at the input boundary.
nonisolated struct SceneRenderPlan: Codable, Equatable, Sendable {
    static let rendererVersion = 2

    var sceneID: UUID
    var durationSeconds: Double
    var sourceGroups: [SceneSourceGroup]
    var clips: [SceneAudioClip]
    var automationCurves: [SceneAutomationCurve]
    var events: [SceneRenderEvent]
    var version: Int

    init(
        sceneID: UUID,
        durationSeconds: Double,
        sourceGroups: [SceneSourceGroup],
        clips: [SceneAudioClip],
        automationCurves: [SceneAutomationCurve] = [],
        events: [SceneRenderEvent] = [],
        version: Int = SceneRenderPlan.rendererVersion
    ) {
        self.sceneID = sceneID
        self.durationSeconds = max(durationSeconds, 0)
        self.sourceGroups = sourceGroups
        self.clips = clips.sorted { lhs, rhs in
            lhs.startSeconds == rhs.startSeconds
                ? lhs.id.uuidString < rhs.id.uuidString
                : lhs.startSeconds < rhs.startSeconds
        }
        self.automationCurves = automationCurves
        self.events = events.sorted { $0.time < $1.time }
        self.version = version
    }
}
