import Foundation

/// Emotional fluid visual modes for `EmotionalFluidView`.
enum FluidSceneType: String, CaseIterable, Identifiable, Hashable {
    case cloud
    case water
    case flame

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cloud: return "云雾"
        case .water: return "水波"
        case .flame: return "暖焰"
        }
    }
}
