import Foundation

nonisolated enum SceneInterpolationMode: String, Codable, Sendable {
    case linear
    case smoothstep
    case recordedLinear = "recorded_linear"
    /// Internal automation-only mode. Position documents do not accept it.
    case hold
}

nonisolated enum SourceGroupDisplayPolicy: String, Codable, Sendable {
    case alwaysInWindow = "always_in_window"
    case whileActive = "while_active"
    case selectedOrActive = "selected_or_active"
}

/// One user-facing source on the spatial mix disk. Multiple timeline clips may
/// feed this group without creating duplicate controls in the UI.
nonisolated struct SceneSourceGroup: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var symbolName: String
    var layer: AudioLayerKind
    var displayPolicy: SourceGroupDisplayPolicy
    var defaultPosition: SpatialPosition
    var positionKeyframes: [ScenePositionKeyframe]

    init(
        id: UUID = UUID(),
        name: String,
        symbolName: String,
        layer: AudioLayerKind,
        displayPolicy: SourceGroupDisplayPolicy = .selectedOrActive,
        defaultPosition: SpatialPosition = .default,
        positionKeyframes: [ScenePositionKeyframe] = []
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.layer = layer
        self.displayPolicy = displayPolicy
        self.defaultPosition = defaultPosition
        self.positionKeyframes = positionKeyframes.sorted { $0.time < $1.time }
    }
}

nonisolated struct ScenePositionKeyframe: Codable, Equatable, Sendable {
    var time: Double
    var position: SpatialPosition
    /// Interpolation used from this keyframe to the following keyframe.
    var interpolation: SceneInterpolationMode

    init(
        time: Double,
        position: SpatialPosition,
        interpolation: SceneInterpolationMode = .linear
    ) {
        self.time = time
        self.position = position
        self.interpolation = interpolation
    }
}
