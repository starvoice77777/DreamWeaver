import Testing
@testable import DreamWeaver

@Suite("Assisted creation draft")
struct AssistedCreationDraftTests {
    @Test("Framework identifiers match the backend contract")
    func frameworkIdentifiers() {
        #expect(AssistedCreationFramework.allCases.map(\.rawValue) == [
            "boundary_gate",
            "enclosure_control",
            "depth_reveal",
            "focus_selector",
            "nearfield_width",
        ])
    }

    @Test("Draft rejects invalid zones, duplicates, and a fifth sound")
    func draftLimits() {
        var draft = AssistedCreationDraft(framework: .boundaryGate, sceneName: "夜行车厢")
        let materials = Array(SpatialEditorMaterial.catalog.prefix(5))

        #expect(draft.add(materials[0], to: .near) == .invalidZone)
        #expect(draft.add(materials[0], to: .outside) == .added)
        #expect(draft.add(materials[0], to: .inside) == .alreadySelected)
        #expect(draft.add(materials[1], to: .inside) == .added)
        #expect(draft.add(materials[2], to: .outside) == .added)
        #expect(draft.add(materials[3], to: .inside) == .added)
        #expect(draft.add(materials[4], to: .outside) == .maximumReached)
        #expect(draft.selections.count == AssistedCreationDraft.maximumSoundCount)
    }

    @Test("Editor seed preserves selection identity and semantic position")
    func editorSeedBridge() throws {
        var draft = AssistedCreationDraft(framework: .boundaryGate, sceneName: "夜行车厢")
        let rain = try #require(SpatialEditorMaterial.catalog.first { $0.id == "rain" })
        let wind = try #require(SpatialEditorMaterial.catalog.first { $0.id == "wind" })
        #expect(draft.add(rain, to: .outside) == .added)
        #expect(draft.add(wind, to: .inside, isSystemSupplement: true) == .added)

        let firstSeed = draft.makeEditorSeed()
        let secondSeed = draft.makeEditorSeed()
        #expect(firstSeed.sceneName == "夜行车厢")
        #expect(firstSeed.soundSources.map(\.id) == secondSeed.soundSources.map(\.id))
        #expect(firstSeed.soundSources.map(\.materialID) == ["rain", "wind"])
        #expect(firstSeed.soundSources[0].defaultPosition == AssistedFrameworkZone.outside.editorPosition)
        #expect(firstSeed.soundSources[1].defaultPosition == AssistedFrameworkZone.inside.editorPosition)
        #expect(firstSeed.soundSources.allSatisfy { $0.keyPoints.count == 1 })
    }
}
