import Foundation
import Testing
@testable import DreamWeaver

@Suite("Scene render plan models")
struct SceneRenderPlanModelTests {
    @Test("Audio clip timing is clamped to a valid interval")
    func clipTimingInvariants() {
        let clip = SceneAudioClip(
            sourceGroupID: TestFixtures.groupID,
            startSeconds: -3,
            endSeconds: -5,
            playbackMode: .oneshot
        )
        #expect(clip.startSeconds == 0)
        #expect(clip.endSeconds == 0)
        #expect(clip.duration == 0)
    }

    @Test("Audio clip offset and fades cannot be negative")
    func clipScalarInvariants() {
        let clip = SceneAudioClip(
            sourceGroupID: TestFixtures.groupID,
            startSeconds: 2,
            endSeconds: 1,
            sourceOffsetSeconds: -1,
            playbackMode: .boundedLoop,
            crossfadeMilliseconds: -2,
            fadeInMilliseconds: -3,
            fadeOutMilliseconds: -4
        )
        #expect(clip.endSeconds == 2)
        #expect(clip.sourceOffsetSeconds == 0)
        #expect(clip.crossfadeMilliseconds == 0)
        #expect(clip.fadeInMilliseconds == 0)
        #expect(clip.fadeOutMilliseconds == 0)
    }

    @Test("Source group position keyframes are sorted by time")
    func groupKeyframesAreSorted() {
        let group = TestFixtures.group(keyframes: [
            ScenePositionKeyframe(time: 10, position: .default),
            ScenePositionKeyframe(time: 1, position: .default),
            ScenePositionKeyframe(time: 5, position: .default)
        ])
        #expect(group.positionKeyframes.map(\.time) == [1, 5, 10])
    }

    @Test("Render plan duration cannot be negative")
    func planDurationInvariant() {
        let plan = SceneRenderPlan(
            sceneID: TestFixtures.sceneID,
            durationSeconds: -10,
            sourceGroups: [],
            clips: []
        )
        #expect(plan.durationSeconds == 0)
    }

    @Test("Clips sort by start time and then stable UUID order")
    func clipsAreStablySorted() {
        let plan = SceneRenderPlan(
            sceneID: TestFixtures.sceneID,
            durationSeconds: 10,
            sourceGroups: [TestFixtures.group()],
            clips: [
                TestFixtures.clip(id: TestFixtures.thirdClipID, start: 0, end: 1),
                TestFixtures.clip(id: TestFixtures.secondClipID, start: 2, end: 3),
                TestFixtures.clip(id: TestFixtures.firstClipID, start: 2, end: 3)
            ]
        )
        #expect(plan.clips.map(\.id) == [
            TestFixtures.thirdClipID,
            TestFixtures.firstClipID,
            TestFixtures.secondClipID
        ])
    }

    @Test("Events sort by execution time")
    func eventsAreSorted() {
        let events = [
            SceneRenderEvent(
                id: TestFixtures.secondClipID,
                time: 5,
                action: .stopClip,
                clipID: TestFixtures.firstClipID
            ),
            SceneRenderEvent(
                id: TestFixtures.firstClipID,
                time: 1,
                action: .startClip,
                clipID: TestFixtures.firstClipID
            )
        ]
        let plan = SceneRenderPlan(
            sceneID: TestFixtures.sceneID,
            durationSeconds: 10,
            sourceGroups: [],
            clips: [],
            events: events
        )
        #expect(plan.events.map(\.time) == [1, 5])
    }

    @Test("Plans default to the current renderer version")
    func rendererVersion() {
        let plan = SceneRenderPlan(
            sceneID: TestFixtures.sceneID,
            durationSeconds: 1,
            sourceGroups: [],
            clips: []
        )
        #expect(plan.version == SceneRenderPlan.rendererVersion)
        #expect(SceneRenderPlan.rendererVersion == 2)
    }
}
