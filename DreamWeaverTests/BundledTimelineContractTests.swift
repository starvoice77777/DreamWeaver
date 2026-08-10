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

    @Test("Rain Eaves v9 resource decodes to the current runtime contract")
    func rainEavesContract() {
        let timeline = LocalTimelineFixture.timeline(for: DemoIDs.rainEavesScene)
        #expect(timeline.scene_id == DemoIDs.rainEavesScene)
        #expect(timeline.version == 11)
        #expect(timeline.duration_hint_seconds == 620)
        #expect(timeline.phrases.isEmpty)
        #expect(timeline.cues.count == 36)
        #expect(timeline.cues.flatMap(\.actions).count == 75)
        #expect(Set(timeline.cues.map(\.id)).count == 36)
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
