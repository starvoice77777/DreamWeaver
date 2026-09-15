import XCTest

@testable import SleepSceneDemo

final class SceneComposerTests: XCTestCase {
    @MainActor
    func testMatchingRainIntoAtmosphereIncreasesActiveCount() {
        let composer = SceneComposer()

        XCTAssertTrue(composer.place(elementID: "rain", in: .atmosphere))
        XCTAssertEqual(composer.activeElementCount, 1)
        XCTAssertEqual(composer.element(for: .atmosphere)?.id, "rain")
    }

    @MainActor
    func testFireplaceIntoAtmosphereLeavesSceneUnchangedAndReportsFeedback() {
        let composer = SceneComposer()

        XCTAssertFalse(composer.place(elementID: "fireplace", in: .atmosphere))
        XCTAssertEqual(composer.activeElementCount, 0)
        XCTAssertNotNil(composer.feedbackMessage)
    }

    @MainActor
    func testSecondAnchorReplacesFirst() {
        let composer = SceneComposer()

        XCTAssertTrue(composer.place(elementID: "fireplace", in: .anchor))
        XCTAssertTrue(composer.place(elementID: "campfire", in: .anchor))

        XCTAssertEqual(composer.activeElementCount, 1)
        XCTAssertEqual(composer.element(for: .anchor)?.id, "campfire")
    }

    @MainActor
    func testExampleSceneLoadsThreeActiveElementsAndTitle() {
        let composer = SceneComposer()

        XCTAssertEqual(composer.sceneTitle, "未命名场景")
        composer.loadExampleScene()

        XCTAssertEqual(composer.activeElementCount, 3)
        XCTAssertEqual(composer.sceneTitle, "雨夜壁炉")
    }

    @MainActor
    func testClearSceneReturnsToZero() {
        let composer = SceneComposer()
        composer.loadExampleScene()

        composer.clearScene()

        XCTAssertEqual(composer.activeElementCount, 0)
        XCTAssertEqual(composer.sceneTitle, "未命名场景")
    }

    @MainActor
    func testRemoveFromSlotReturnsToZero() {
        let composer = SceneComposer()
        XCTAssertTrue(composer.place(elementID: "rain", in: .atmosphere))

        composer.remove(from: .atmosphere)

        XCTAssertEqual(composer.activeElementCount, 0)
        XCTAssertNil(composer.element(for: .atmosphere))
    }

    @MainActor
    func testUnknownElementIDReturnsFalseWithoutChangingPlacementsAndReportsFeedback() {
        let composer = SceneComposer()
        XCTAssertTrue(composer.place(elementID: "rain", in: .atmosphere))
        let placementsBefore = composer.placements

        XCTAssertFalse(composer.place(elementID: "unknown-element", in: .detail))

        XCTAssertEqual(composer.placements, placementsBefore)
        XCTAssertNotNil(composer.feedbackMessage)
    }

    @MainActor
    func testCategoryMismatchDoesNotChangeExistingPlacement() {
        let composer = SceneComposer()
        XCTAssertTrue(composer.place(elementID: "rain", in: .atmosphere))
        let placementsBefore = composer.placements

        XCTAssertFalse(composer.place(elementID: "fireplace", in: .atmosphere))

        XCTAssertEqual(composer.placements, placementsBefore)
        XCTAssertEqual(composer.element(for: .atmosphere)?.id, "rain")
        XCTAssertNotNil(composer.feedbackMessage)
    }

    @MainActor
    func testFilteredElementsFollowActiveFilter() {
        let composer = SceneComposer()

        composer.activeFilter = .anchor

        XCTAssertFalse(composer.filteredElements.isEmpty)
        XCTAssertTrue(composer.filteredElements.allSatisfy { $0.category == .anchor })
        XCTAssertEqual(Set(composer.filteredElements.map(\.id)), Set(["fireplace", "campfire"]))

        composer.activeFilter = nil
        XCTAssertEqual(composer.filteredElements.count, SoundElement.catalog.count)
    }

    @MainActor
    func testSceneSubtitleAndAtmosphereSummaryUpdateForEmptyAndExampleScenes() {
        let composer = SceneComposer()

        XCTAssertEqual(composer.sceneSubtitle, "拖入声音，搭建今晚的安静角落")
        XCTAssertEqual(composer.atmosphereSummary, "还没有声音，先添加一个元素")

        composer.loadExampleScene()

        XCTAssertEqual(composer.sceneSubtitle, "3 个声音，组成你的安静角落")
        XCTAssertEqual(composer.atmosphereSummary, "Rain · Fireplace · Page Turning")
    }

    @MainActor
    func testActiveElementsFollowVisualLayerOrder() {
        let composer = SceneComposer()

        XCTAssertTrue(composer.place(elementID: "page-turning", in: .detail))
        XCTAssertTrue(composer.place(elementID: "rain", in: .atmosphere))
        XCTAssertTrue(composer.place(elementID: "fireplace", in: .anchor))

        XCTAssertEqual(composer.activeElements.map(\.id), ["rain", "fireplace", "page-turning"])
    }

    @MainActor
    func testPlaceOnCanvasUsesElementDefaultSlot() {
        let composer = SceneComposer()

        XCTAssertTrue(composer.placeOnCanvas(elementID: "rain"))
        XCTAssertEqual(composer.element(for: .atmosphere)?.id, "rain")
        XCTAssertNil(composer.feedbackMessage)
    }

    func testSoundElementsMapToDistinctCanvasIllustrationsAndLayers() {
        XCTAssertEqual(SoundElement.catalog.first(where: { $0.id == "rain" })?.illustrationKind, .rain)
        XCTAssertEqual(SoundElement.catalog.first(where: { $0.id == "fireplace" })?.illustrationKind, .fireplace)
        XCTAssertEqual(SoundElement.catalog.first(where: { $0.id == "page-turning" })?.illustrationKind, .book)
        XCTAssertEqual(SceneSlotKind.environment.illustrationLayer, .background)
        XCTAssertEqual(SceneSlotKind.anchor.illustrationLayer, .subject)
        XCTAssertEqual(SceneSlotKind.detail.illustrationLayer, .foreground)
    }
}
