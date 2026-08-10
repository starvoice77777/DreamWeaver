import CoreGraphics
import Foundation
import Testing
@testable import DreamWeaver

@Suite("Scene plan compiler")
struct ScenePlanCompilerTests {
    @Test("Version-one composition compiles tracks into groups, clips, and events")
    func versionOneCompilation() throws {
        let firstTrack = APIContentDTO.CompositionTrack(
            id: TestFixtures.firstClipID,
            asset_id: TestFixtures.assetID,
            resource_key: "rain_soft",
            layer: AudioLayerKind.environment.rawValue,
            loop: true,
            start_seconds: 2,
            end_seconds: 8,
            source_duration_seconds: 12,
            keyframes: [
                APIContentDTO.CompositionKeyframe(
                    t: 2,
                    angle: 0.25,
                    radius: 0.4,
                    interpolation: SceneInterpolationMode.linear.rawValue
                )
            ]
        )
        let secondTrack = APIContentDTO.CompositionTrack(
            id: TestFixtures.secondClipID,
            asset_id: nil,
            resource_key: "wind_gust",
            layer: AudioLayerKind.trigger.rawValue,
            loop: false,
            start_seconds: 1,
            end_seconds: 4,
            source_duration_seconds: nil,
            keyframes: []
        )
        let composition = APIContentDTO.SceneComposition(
            schema: "scene_composition_v1",
            version: 1,
            duration_seconds: 20,
            tracks: [firstTrack, secondTrack]
        )

        let plan = ScenePlanCompiler.compile(composition: composition, sceneID: TestFixtures.sceneID)
        #expect(plan.sceneID == TestFixtures.sceneID)
        #expect(plan.durationSeconds == 20)
        #expect(Set(plan.sourceGroups.map(\.id)) == Set([firstTrack.id, secondTrack.id]))
        #expect(Set(plan.clips.map(\.id)) == Set([firstTrack.id, secondTrack.id]))

        let loopClip = try #require(plan.clips.first { $0.id == firstTrack.id })
        #expect(loopClip.sourceGroupID == firstTrack.id)
        #expect(loopClip.assetID == TestFixtures.assetID)
        #expect(loopClip.resourceKey == "rain_soft")
        #expect(loopClip.startSeconds == 2)
        #expect(loopClip.endSeconds == 8)
        #expect(loopClip.playbackMode == .boundedLoop)
        #expect(loopClip.crossfadeMilliseconds == 1_000)
        #expect(loopClip.masteringProfileKey == "rain_soft")

        let oneShot = try #require(plan.clips.first { $0.id == secondTrack.id })
        #expect(oneShot.playbackMode == .oneshot)
        #expect(oneShot.crossfadeMilliseconds == 0)
        #expect(plan.events.count == 4)
        #expect(plan.events.map(\.time) == [1, 2, 4, 8])
        #expect(plan.events.filter { $0.action == .startClip }.count == 2)
        #expect(plan.events.filter { $0.action == .stopClip }.count == 2)
    }

    @Test("Version-one duration falls back to the latest clip end")
    func versionOneDurationFallback() {
        let track = APIContentDTO.CompositionTrack(
            id: TestFixtures.firstClipID,
            asset_id: nil,
            resource_key: "rain_soft",
            layer: nil,
            loop: true,
            start_seconds: 3,
            end_seconds: 17,
            source_duration_seconds: nil,
            keyframes: []
        )
        let composition = APIContentDTO.SceneComposition(
            schema: "scene_composition_v1",
            version: 1,
            duration_seconds: nil,
            tracks: [track]
        )
        #expect(ScenePlanCompiler.compile(
            composition: composition,
            sceneID: TestFixtures.sceneID
        ).durationSeconds == 17)
    }

    @Test("Version-two composition preserves group and clip fields with documented fallbacks")
    func versionTwoFieldPreservation() throws {
        let firstGroup = APIContentDTO.CompositionSourceGroup(
            id: TestFixtures.groupID,
            name: "Shared rain",
            symbol_name: "   ",
            layer: "unknown-layer",
            display_policy: SourceGroupDisplayPolicy.alwaysInWindow.rawValue,
            position_keyframes: [
                APIContentDTO.CompositionKeyframe(
                    t: 0,
                    angle: 0.3,
                    radius: 0.4,
                    interpolation: SceneInterpolationMode.smoothstep.rawValue
                )
            ]
        )
        let secondGroup = APIContentDTO.CompositionSourceGroup(
            id: TestFixtures.secondGroupID,
            name: "Voice",
            symbol_name: "quote.bubble",
            layer: AudioLayerKind.voice.rawValue,
            display_policy: nil,
            position_keyframes: []
        )
        let firstClip = APIContentDTO.CompositionClip(
            id: TestFixtures.firstClipID,
            source_group_id: TestFixtures.groupID,
            asset_id: TestFixtures.assetID,
            resource_key: "rain_soft",
            start_seconds: 1,
            end_seconds: 4,
            source_offset_seconds: 0.75,
            playback_mode: ScenePlaybackMode.boundedLoop.rawValue,
            crossfade_ms: 850,
            fade_in_ms: 120,
            fade_out_ms: 240,
            phrase_id: TestFixtures.phraseID,
            text_cue_id: TestFixtures.textCueID,
            mastering_profile_key: "rain-master"
        )
        let secondClip = APIContentDTO.CompositionClip(
            id: TestFixtures.secondClipID,
            source_group_id: TestFixtures.groupID,
            asset_id: nil,
            resource_key: "wind_gust",
            start_seconds: 5,
            end_seconds: 9,
            source_offset_seconds: nil,
            playback_mode: "future-mode",
            crossfade_ms: nil,
            fade_in_ms: nil,
            fade_out_ms: nil,
            phrase_id: nil,
            text_cue_id: nil,
            mastering_profile_key: nil
        )
        let composition = APIContentDTO.SceneComposition(
            schema: "scene_composition_v2",
            version: 1,
            duration_seconds: nil,
            source_groups: [secondGroup, firstGroup],
            clips: [secondClip, firstClip]
        )

        let plan = ScenePlanCompiler.compile(composition: composition, sceneID: TestFixtures.sceneID)
        #expect(plan.durationSeconds == 9)
        #expect(plan.sourceGroups.map(\.id) == [TestFixtures.groupID, TestFixtures.secondGroupID])
        #expect(plan.clips.allSatisfy { clip in
            plan.sourceGroups.contains { $0.id == clip.sourceGroupID }
        })

        let group = try #require(plan.sourceGroups.first { $0.id == TestFixtures.groupID })
        #expect(group.name == "Shared rain")
        #expect(group.symbolName == "waveform")
        #expect(group.layer == .ambience)
        #expect(group.displayPolicy == .whileActive)
        #expect(group.positionKeyframes.first?.interpolation == .smoothstep)

        let preserved = try #require(plan.clips.first { $0.id == firstClip.id })
        #expect(preserved.sourceGroupID == TestFixtures.groupID)
        #expect(preserved.assetID == TestFixtures.assetID)
        #expect(preserved.resourceKey == "rain_soft")
        #expect(preserved.sourceOffsetSeconds == 0.75)
        #expect(preserved.playbackMode == .boundedLoop)
        #expect(preserved.crossfadeMilliseconds == 850)
        #expect(preserved.fadeInMilliseconds == 120)
        #expect(preserved.fadeOutMilliseconds == 240)
        #expect(preserved.phraseID == TestFixtures.phraseID)
        #expect(preserved.textCueID == TestFixtures.textCueID)
        #expect(preserved.masteringProfileKey == "rain-master")

        let fallback = try #require(plan.clips.first { $0.id == secondClip.id })
        #expect(fallback.playbackMode == .oneshot)
        #expect(fallback.sourceGroupID == TestFixtures.groupID)
        #expect(plan.events.filter { $0.clipID == firstClip.id }.map(\.time) == [1, 4])
        #expect(plan.events.filter { $0.clipID == secondClip.id }.map(\.time) == [5, 9])
    }

    @Test("Compiler inserts a hold guard across an unauthored clip gap")
    func gapGuardInsertion() throws {
        let group = APIContentDTO.CompositionSourceGroup(
            id: TestFixtures.groupID,
            name: "Rain",
            symbol_name: "cloud.rain",
            layer: AudioLayerKind.ambience.rawValue,
            display_policy: nil,
            position_keyframes: [
                APIContentDTO.CompositionKeyframe(t: 0, angle: 0, radius: 0.2),
                APIContentDTO.CompositionKeyframe(t: 5, angle: 1, radius: 0.8)
            ]
        )
        let clips = [
            APIContentDTO.CompositionClip(
                id: TestFixtures.firstClipID,
                source_group_id: TestFixtures.groupID,
                asset_id: nil,
                resource_key: "rain_soft",
                start_seconds: 0,
                end_seconds: 2,
                source_offset_seconds: nil,
                playback_mode: "bounded_loop",
                crossfade_ms: nil,
                fade_in_ms: nil,
                fade_out_ms: nil,
                phrase_id: nil,
                text_cue_id: nil,
                mastering_profile_key: nil
            ),
            APIContentDTO.CompositionClip(
                id: TestFixtures.secondClipID,
                source_group_id: TestFixtures.groupID,
                asset_id: nil,
                resource_key: "rain_soft",
                start_seconds: 5,
                end_seconds: 7,
                source_offset_seconds: nil,
                playback_mode: "bounded_loop",
                crossfade_ms: nil,
                fade_in_ms: nil,
                fade_out_ms: nil,
                phrase_id: nil,
                text_cue_id: nil,
                mastering_profile_key: nil
            )
        ]
        let composition = APIContentDTO.SceneComposition(
            schema: "scene_composition_v2",
            version: 1,
            duration_seconds: 7,
            source_groups: [group],
            clips: clips
        )
        let plan = ScenePlanCompiler.compile(composition: composition, sceneID: TestFixtures.sceneID)
        let compiled = try #require(plan.sourceGroups.first)
        let guardFrame = try #require(compiled.positionKeyframes.first { $0.time == 2 })
        #expect(guardFrame.interpolation == .hold)
        #expect(guardFrame.position == SpatialPosition(angle: 0, radius: 0.2))
    }

    @Test("An explicit keyframe in a clip gap is never replaced by a hold guard")
    func explicitGapFrameWins() throws {
        let group = APIContentDTO.CompositionSourceGroup(
            id: TestFixtures.groupID,
            name: "Rain",
            symbol_name: "cloud.rain",
            layer: AudioLayerKind.ambience.rawValue,
            display_policy: nil,
            position_keyframes: [
                APIContentDTO.CompositionKeyframe(t: 0, angle: 0, radius: 0.2),
                APIContentDTO.CompositionKeyframe(t: 3, angle: 0.5, radius: 0.5),
                APIContentDTO.CompositionKeyframe(t: 5, angle: 1, radius: 0.8)
            ]
        )
        let clips = [
            TestCompilerDTO.clip(id: TestFixtures.firstClipID, start: 0, end: 2),
            TestCompilerDTO.clip(id: TestFixtures.secondClipID, start: 5, end: 7)
        ]
        let composition = APIContentDTO.SceneComposition(
            schema: "scene_composition_v2",
            version: 1,
            duration_seconds: 7,
            source_groups: [group],
            clips: clips
        )
        let plan = ScenePlanCompiler.compile(composition: composition, sceneID: TestFixtures.sceneID)
        let compiled = try #require(plan.sourceGroups.first)
        #expect(compiled.positionKeyframes.contains { $0.time == 3 && $0.position.radius == 0.5 })
        #expect(!compiled.positionKeyframes.contains { $0.interpolation == .hold })
    }

    @Test("Editor sources compile into shared groups and independent playable clips")
    func editorSourceCompilation() throws {
        var first = TestFixtures.editorSource(
            id: TestFixtures.firstClipID,
            start: 0,
            duration: 4
        )
        first.motionClips = [SpatialMotionClip(samples: [
            SpatialMotionSample(time: 1, position: CGPoint(x: 0.1, y: -0.4)),
            SpatialMotionSample(time: 2, position: CGPoint(x: 0.2, y: -0.3))
        ])]
        let second = TestFixtures.editorSource(
            id: TestFixtures.secondClipID,
            start: 9,
            duration: 10,
            looping: false
        )
        let voice = TestFixtures.editorSource(
            id: TestFixtures.thirdClipID,
            groupID: TestFixtures.secondGroupID,
            materialID: "voice",
            resourceName: "voice_phrase_01",
            start: 4,
            duration: 3,
            looping: false,
            isVoice: true
        )
        let customID = UUID(uuidString: "30000000-0000-4000-8000-000000000004")!
        let custom = TestFixtures.editorSource(
            id: customID,
            groupID: UUID(uuidString: "20000000-0000-4000-8000-000000000004")!,
            materialID: "custom",
            assetID: nil,
            resourceName: nil,
            start: 0,
            duration: 5
        )

        let plan = ScenePlanCompiler.compile(
            editorSources: [second, voice, custom, first],
            sceneID: TestFixtures.sceneID,
            duration: 12
        )
        #expect(plan.sourceGroups.filter { $0.id == TestFixtures.groupID }.count == 1)
        #expect(plan.clips.filter { $0.sourceGroupID == TestFixtures.groupID }.count == 2)
        #expect(!plan.clips.contains { $0.id == customID })
        #expect(plan.clips.count == 3)
        #expect(plan.events.count == 6)

        let bounded = try #require(plan.clips.first { $0.id == first.id })
        #expect(bounded.playbackMode == .boundedLoop)
        let clipped = try #require(plan.clips.first { $0.id == second.id })
        #expect(clipped.playbackMode == .oneshot)
        #expect(clipped.endSeconds == 12)
        let voiceClip = try #require(plan.clips.first { $0.id == voice.id })
        #expect(voiceClip.phraseID == voice.id)
        #expect(voiceClip.playbackMode == .oneshot)

        let sharedGroup = try #require(plan.sourceGroups.first { $0.id == TestFixtures.groupID })
        #expect(sharedGroup.positionKeyframes.contains { $0.interpolation == .recordedLinear })
        #expect(plan.version == SceneRenderPlan.rendererVersion)
    }
}

private nonisolated enum TestCompilerDTO {
    static func clip(id: UUID, start: Double, end: Double) -> APIContentDTO.CompositionClip {
        APIContentDTO.CompositionClip(
            id: id,
            source_group_id: TestFixtures.groupID,
            asset_id: nil,
            resource_key: "rain_soft",
            start_seconds: start,
            end_seconds: end,
            source_offset_seconds: nil,
            playback_mode: "bounded_loop",
            crossfade_ms: nil,
            fade_in_ms: nil,
            fade_out_ms: nil,
            phrase_id: nil,
            text_cue_id: nil,
            mastering_profile_key: nil
        )
    }
}
