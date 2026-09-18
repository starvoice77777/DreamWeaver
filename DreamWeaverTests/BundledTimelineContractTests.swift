import Foundation
import Testing
@testable import DreamWeaver

@Suite("Bundled timeline contracts")
struct BundledTimelineContractTests {
    @Test("Hair Care v11 resource decodes to the current runtime contract")
    func hairCareContract() {
        let timeline = LocalTimelineFixture.timeline(for: DemoIDs.hairCareScene)
        #expect(timeline.scene_id == DemoIDs.hairCareScene)
        #expect(timeline.version == 12)
        #expect(timeline.duration_hint_seconds == 620)
        #expect(timeline.phrases.count == 20)
        #expect(timeline.cues.count == 138)
        #expect(timeline.cues.flatMap(\.actions).count == 242)
        #expect(Set(timeline.phrases.map(\.id)).count == 20)
        #expect(timeline.phrases.allSatisfy { phrase in
            let binding = phrase.voice_binding
            return binding.kind == "official_resource"
                && binding.resource_key?.isEmpty == false
                && binding.track_id != nil
                && binding.track_layer == AudioLayerKind.voice.rawValue
        })
    }

    @Test("Rain Eaves v1.2 resource decodes to the current runtime contract")
    func rainEavesContract() {
        let timeline = LocalTimelineFixture.timeline(for: DemoIDs.rainEavesScene)
        #expect(timeline.scene_id == DemoIDs.rainEavesScene)
        #expect(timeline.version == 12)
        #expect(timeline.duration_hint_seconds == 620)
        #expect(timeline.phrases.isEmpty)
        #expect(timeline.cues.count == 27)
        #expect(timeline.cues.flatMap(\.actions).count == 59)
        #expect(Set(timeline.cues.map(\.id)).count == 27)
        #expect(timeline.cues.allSatisfy { cue in
            let absoluteTimeIsValid = cue.at_seconds.map { $0 >= 0 && $0 <= 620 } ?? true
            let progressIsValid = cue.progress.map { $0 >= 0 && $0 <= 1 } ?? true
            let repeatIsValid = cue.repeat_every_seconds.map { $0 > 0 } ?? true
            let untilIsValid = cue.until_seconds.map { $0 >= 0 && $0 <= 620 } ?? true
            return (cue.at_seconds != nil || cue.progress != nil)
                && absoluteTimeIsValid
                && progressIsValid
                && repeatIsValid
                && untilIsValid
        })
    }

    @Test("Rain handoff gains and playback windows survive the runtime compiler")
    func rainAuthoredPlayback() throws {
        let scene = try #require(MockDataService.makeScenes().first { $0.id == DemoIDs.rainEavesScene })
        let plan = ScenePlanCompiler.compile(
            timeline: LocalTimelineFixture.timeline(for: scene.id), scene: scene
        )
        #expect(plan.clips.count == 5)
        #expect(plan.clips.first { $0.sourceGroupID == DemoIDs.sourceRainSoftFar }?.startSeconds == 0)
        #expect(plan.clips.first { $0.sourceGroupID == DemoIDs.sourceRain }?.startSeconds == 30)
        #expect(plan.clips.first { $0.sourceGroupID == DemoIDs.sourceRainBambooLeaf }?.startSeconds == 220)
        for (id, time, expected) in [
            (DemoIDs.sourceRainSoftFar, 30.0, 0.22),
            (DemoIDs.sourceRain, 340.0, 0.46),
            (DemoIDs.sourceRain, 360.0, 0.4),
            (DemoIDs.sourceWind, 458.0, 0.18)
        ] {
            let curve = try #require(plan.automationCurves.first { $0.target == .sourceGroup(id) })
            #expect(approximatelyEqual(
                SpatialTrajectoryEvaluator.automationValue(at: time, keyframes: curve.keyframes),
                expected
            ))
        }
    }

    @Test("Unknown scenes receive an empty identity-preserving timeline")
    func unknownSceneContract() {
        let unknown = UUID(uuidString: "90000000-0000-4000-8000-000000000001")!
        let timeline = LocalTimelineFixture.timeline(for: unknown)
        #expect(timeline.scene_id == unknown)
        #expect(timeline.version == 1)
        #expect(timeline.phrases.isEmpty)
        #expect(timeline.cues.isEmpty)
        #expect(timeline.duration_hint_seconds == 2_700)
    }
}
