import Foundation
import Observation

@MainActor
@Observable
final class SceneComposer {
    var placements: [SceneSlotKind: SoundElement] = [:]
    var selectedElementID: String?
    var activeFilter: SoundCategory?
    var isPlaying = false
    var feedbackMessage: String?
    var intensity = 0.7
    var distance = 0.5
    var activity = 0.3

    // Future: connect this element to an AudioTrack and parameter automation.

    var activeElementCount: Int {
        min(placements.count, SceneSlotKind.allCases.count)
    }

    var activeElements: [SoundElement] {
        SceneSlotKind.allCases.compactMap { placements[$0] }
    }

    var sceneTitle: String {
        guard activeElementCount > 0 else { return "未命名场景" }

        let rain = placements[.atmosphere]?.id == "rain"
        let fireplace = placements[.anchor]?.id == "fireplace"
        if rain && fireplace { return "雨夜壁炉" }

        let names = SceneSlotKind.allCases.compactMap { placements[$0]?.name }
        return names.prefix(2).joined(separator: " · ")
    }

    var sceneSubtitle: String {
        guard activeElementCount > 0 else { return "拖入声音，搭建今晚的安静角落" }
        return "\(activeElementCount) 个声音，组成你的安静角落"
    }

    var atmosphereSummary: String {
        guard activeElementCount > 0 else { return "还没有声音，先添加一个元素" }
        let names = SceneSlotKind.allCases.compactMap { placements[$0]?.name }
        return names.joined(separator: " · ")
    }

    func element(for slot: SceneSlotKind) -> SoundElement? {
        placements[slot]
    }

    @discardableResult
    func placeOnCanvas(elementID: String) -> Bool {
        guard let element = SoundElement.catalog.first(where: { $0.id == elementID }) else {
            feedbackMessage = "找不到声音：\(elementID)"
            return false
        }
        return place(element, in: element.defaultSlot)
    }

    var filteredElements: [SoundElement] {
        guard let activeFilter else { return SoundElement.catalog }
        return SoundElement.catalog.filter { $0.category == activeFilter }
    }

    @discardableResult
    func place(elementID: String, in slot: SceneSlotKind) -> Bool {
        guard let element = SoundElement.catalog.first(where: { $0.id == elementID }) else {
            feedbackMessage = "找不到声音：\(elementID)"
            return false
        }
        return place(element, in: slot)
    }

    @discardableResult
    func place(_ element: SoundElement, in slot: SceneSlotKind) -> Bool {
        guard slot.acceptedCategories.contains(element.category) else {
            feedbackMessage = "请放入“\(slot.title)”声音"
            return false
        }

        placements[slot] = element
        feedbackMessage = nil
        return true
    }

    func remove(from slot: SceneSlotKind) {
        placements.removeValue(forKey: slot)
        feedbackMessage = nil
    }

    func clearScene() {
        placements.removeAll()
        selectedElementID = nil
        isPlaying = false
        feedbackMessage = nil
    }

    func loadExampleScene() {
        placements.removeAll()
        _ = place(elementID: "rain", in: .atmosphere)
        _ = place(elementID: "fireplace", in: .anchor)
        _ = place(elementID: "page-turning", in: .detail)
        selectedElementID = nil
        isPlaying = false
        feedbackMessage = nil
    }
}
