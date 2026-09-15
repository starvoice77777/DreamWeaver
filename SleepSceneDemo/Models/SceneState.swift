import Foundation

struct SceneState: Equatable {
    var placements: [SceneSlotKind: SoundElement] = [:]
    var selectedElementID: String?
    var activeFilter: SoundCategory?
    var isPlaying = false
    var feedbackMessage: String?
    var intensity = 0.7
    var distance = 0.5
    var activity = 0.3

    var activeElementCount: Int { placements.count }
}
