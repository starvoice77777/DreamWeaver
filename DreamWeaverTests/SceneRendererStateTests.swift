import Foundation
import Testing
@testable import DreamWeaver

@Suite("Scene renderer state")
@MainActor
struct SceneRendererStateTests {
    private func plan(
        duration: Double = 10,
        groups: [SceneSourceGroup]? = nil,
        clips: [SceneAudioClip]? = nil,
        curves: [SceneAutomationCurve] = []
    ) -> SceneRenderPlan {
        SceneRenderPlan(
            sceneID: TestFixtures.sceneID,
            durationSeconds: duration,
            sourceGroups: groups ?? [TestFixtures.group()],
            clips: clips ?? [TestFixtures.clip()],
            automationCurves: curves
        )
    }

    @Test("A new renderer starts empty")
    func initialState() {
        let renderer = SceneRenderer()
        #expect(renderer.state == .empty)
        #expect(renderer.plan == nil)
    }

    @Test("Load publishes the requested clamped time")
    func loadTimeClamping() {
        let renderer = SceneRenderer()
        renderer.load(plan(), at: 4)
        #expect(renderer.state.time == 4)
        #expect(!renderer.state.isPlaying)

        renderer.load(plan(), at: -2)
        #expect(renderer.state.time == 0)
        renderer.load(plan(), at: 50)
        #expect(renderer.state.time == 10)
    }

    @Test("Seek clamps to the plan duration without starting playback")
    func seekTimeClamping() {
        let renderer = SceneRenderer()
        renderer.load(plan())
        renderer.seek(to: -10)
        #expect(renderer.state.time == 0)
        renderer.seek(to: 20)
        #expect(renderer.state.time == 10)
        #expect(!renderer.state.isPlaying)
    }

    @Test("Clip activity includes start and excludes end")
    func activeIntervalBoundary() {
        let renderer = SceneRenderer()
        renderer.load(plan(), at: 1)
        #expect(renderer.state.activeClipIDs == [TestFixtures.firstClipID])
        #expect(renderer.state.sourceGroups.first?.isActive == true)

        renderer.seek(to: 3)
        #expect(renderer.state.activeClipIDs.isEmpty)
        #expect(renderer.state.sourceGroups.first?.isActive == false)
    }

    @Test("Multiple clips publish correct global and per-group activity")
    func multipleClipActivity() throws {
        let groups = [
            TestFixtures.group(id: TestFixtures.groupID),
            TestFixtures.group(id: TestFixtures.secondGroupID)
        ]
        let clips = [
            TestFixtures.clip(
                id: TestFixtures.firstClipID,
                groupID: TestFixtures.groupID,
                start: 0,
                end: 5
            ),
            TestFixtures.clip(
                id: TestFixtures.secondClipID,
                groupID: TestFixtures.groupID,
                start: 2,
                end: 6
            ),
            TestFixtures.clip(
                id: TestFixtures.thirdClipID,
                groupID: TestFixtures.secondGroupID,
                start: 3,
                end: 4
            )
        ]
        let renderer = SceneRenderer()
        renderer.load(plan(groups: groups, clips: clips), at: 3.5)
        #expect(renderer.state.activeClipIDs == Set(clips.map(\.id)))

        let firstGroup = try #require(renderer.state.sourceGroups.first {
            $0.id == TestFixtures.groupID
        })
        #expect(firstGroup.activeClipIDs == [TestFixtures.firstClipID, TestFixtures.secondClipID])
        #expect(firstGroup.isActive)
        let secondGroup = try #require(renderer.state.sourceGroups.first {
            $0.id == TestFixtures.secondGroupID
        })
        #expect(secondGroup.activeClipIDs == [TestFixtures.thirdClipID])
    }

    @Test("Published position and radial gain come from the shared math")
    func positionAndRadialGain() throws {
        let frames = [
            ScenePositionKeyframe(
                time: 0,
                position: SpatialPosition(angle: 0, radius: 0.2),
                interpolation: .linear
            ),
            ScenePositionKeyframe(
                time: 10,
                position: SpatialPosition(angle: 1, radius: 0.8)
            )
        ]
        let group = TestFixtures.group(keyframes: frames)
        let renderer = SceneRenderer()
        renderer.load(plan(groups: [group]), at: 5)
        let state = try #require(renderer.state.sourceGroups.first)
        #expect(approximatelyEqual(state.position.angle, 0.5))
        #expect(approximatelyEqual(state.position.radius, 0.5))
        #expect(approximatelyEqual(
            state.radialGain,
            RadialGainCurve.gain(forRadius: 0.5)
        ))
    }

    @Test("Only matching source-group automation curves multiply into gain")
    func matchingAutomationCurves() throws {
        let curves = [
            SceneAutomationCurve(
                id: TestFixtures.curveID,
                target: .sourceGroup(TestFixtures.groupID),
                parameter: .envelope,
                keyframes: [SceneAutomationKeyframe(time: 0, value: 0.5, interpolation: .linear)],
                priority: 0
            ),
            SceneAutomationCurve(
                id: TestFixtures.secondClipID,
                target: .sourceGroup(TestFixtures.groupID),
                parameter: .duck,
                keyframes: [SceneAutomationKeyframe(time: 0, value: 0.8, interpolation: .linear)],
                priority: 1
            ),
            SceneAutomationCurve(
                id: TestFixtures.thirdClipID,
                target: .sourceGroup(TestFixtures.secondGroupID),
                parameter: .envelope,
                keyframes: [SceneAutomationKeyframe(time: 0, value: 0.1, interpolation: .linear)],
                priority: 0
            ),
            SceneAutomationCurve(
                id: TestFixtures.firstClipID,
                target: .clip(TestFixtures.firstClipID),
                parameter: .envelope,
                keyframes: [SceneAutomationKeyframe(time: 0, value: 0.2, interpolation: .linear)],
                priority: 0
            )
        ]
        let renderer = SceneRenderer()
        renderer.load(plan(curves: curves), at: 2)
        let group = try #require(renderer.state.sourceGroups.first)
        #expect(approximatelyEqual(group.automationGain, 0.4))
    }

    @Test("Manual position overrides and clearing restores trajectory evaluation")
    func manualPositionOverride() throws {
        let frames = [
            ScenePositionKeyframe(
                time: 0,
                position: SpatialPosition(angle: 0, radius: 0.2),
                interpolation: .linear
            ),
            ScenePositionKeyframe(
                time: 10,
                position: SpatialPosition(angle: 1, radius: 0.8)
            )
        ]
        let renderer = SceneRenderer()
        renderer.load(plan(groups: [TestFixtures.group(keyframes: frames)]), at: 5)
        let manual = SpatialPosition(angle: -1, radius: 0.9)
        renderer.setManualPosition(manual, for: TestFixtures.groupID)
        #expect(renderer.state.sourceGroups.first?.position == manual)

        renderer.clearManualPosition(for: TestFixtures.groupID)
        let restored = try #require(renderer.state.sourceGroups.first?.position)
        #expect(approximatelyEqual(restored.angle, 0.5))
        #expect(approximatelyEqual(restored.radius, 0.5))
    }

    @Test("Stop resets time and playback state")
    func stopState() {
        let renderer = SceneRenderer()
        renderer.load(plan(), at: 2)
        renderer.stop()
        #expect(renderer.state.time == 0)
        #expect(!renderer.state.isPlaying)
    }

    @Test("State-change callback receives deterministic load, seek, and stop states")
    func stateChangeCallback() {
        let renderer = SceneRenderer()
        var states: [RendererState] = []
        renderer.onStateChange = { states.append($0) }
        renderer.load(plan(), at: 1)
        renderer.seek(to: 2)
        renderer.stop()
        #expect(states.map(\.time) == [1, 2, 0])
        #expect(states.allSatisfy { !$0.isPlaying })
    }
}
