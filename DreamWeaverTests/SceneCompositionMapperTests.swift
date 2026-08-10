import CoreGraphics
import Foundation
import Testing
@testable import DreamWeaver

@Suite("Create composition mapper")
struct SceneCompositionMapperTests {
    @Test("Shared editor clips persist as one source group with independent clip fields")
    func sharedGroupComposition() throws {
        var first = TestFixtures.editorSource(
            id: TestFixtures.firstClipID,
            start: 1,
            duration: 3,
            looping: true
        )
        first.sourceOffsetSeconds = 0.75
        first.crossfadeMilliseconds = 850
        first.fadeInMilliseconds = 110
        first.fadeOutMilliseconds = 220
        let second = TestFixtures.editorSource(
            id: TestFixtures.secondClipID,
            start: 6,
            duration: 2,
            looping: false
        )

        let composition = SceneCompositionMapper.composition(
            from: [first, second],
            duration: 12
        )
        #expect(composition.schema == "scene_composition_v2")
        #expect(composition.source_groups?.count == 1)
        #expect(composition.clips?.count == 2)

        let firstClip = try #require(composition.clips?.first { $0.id == first.id })
        #expect(firstClip.source_group_id == TestFixtures.groupID)
        #expect(firstClip.start_seconds == 1)
        #expect(firstClip.end_seconds == 4)
        #expect(firstClip.source_offset_seconds == 0.75)
        #expect(firstClip.playback_mode == ScenePlaybackMode.boundedLoop.rawValue)
        #expect(firstClip.crossfade_ms == 850)
        #expect(firstClip.fade_in_ms == 110)
        #expect(firstClip.fade_out_ms == 220)

        let secondClip = try #require(composition.clips?.first { $0.id == second.id })
        #expect(secondClip.playback_mode == ScenePlaybackMode.oneshot.rawValue)
        #expect(firstClip.id != secondClip.id)
    }

    @Test("Voice clips map to the voice layer and retain phrase identity")
    func voiceMapping() throws {
        let voice = TestFixtures.editorSource(
            id: TestFixtures.phraseID,
            groupID: TestFixtures.secondGroupID,
            materialID: "voice",
            resourceName: "voice_phrase_01",
            start: 2,
            duration: 4,
            looping: false,
            isVoice: true
        )
        let composition = SceneCompositionMapper.composition(from: [voice], duration: 10)
        let group = try #require(composition.source_groups?.first)
        let clip = try #require(composition.clips?.first)
        #expect(group.layer == AudioLayerKind.voice.rawValue)
        #expect(clip.phrase_id == voice.id)
        #expect(clip.playback_mode == ScenePlaybackMode.oneshot.rawValue)
        #expect(clip.resource_key == "voice_phrase_01")
        #expect(clip.mastering_profile_key == "voice_phrase_01")
    }

    @Test("Cartesian trajectories map to the expected polar angle and radius")
    func cartesianToPolar() throws {
        let keyPoint = SpatialKeyPoint(
            time: 3,
            position: CGPoint(x: 0.3, y: -0.4),
            interpolation: .linear
        )
        let source = TestFixtures.editorSource(keyPoints: [keyPoint])
        let composition = SceneCompositionMapper.composition(from: [source], duration: 10)
        let frame = try #require(composition.source_groups?.first?.position_keyframes.first)
        #expect(approximatelyEqual(frame.radius, 0.5))
        #expect(approximatelyEqual(frame.angle, atan2(0.3, 0.4)))
        #expect(frame.interpolation == SceneInterpolationMode.linear.rawValue)
    }

    @Test("Composition duration and clip ranges are clamped to valid values")
    func compositionTimingClamps() throws {
        let late = TestFixtures.editorSource(start: 10, duration: 8)
        let composition = SceneCompositionMapper.composition(from: [late], duration: 5)
        let clip = try #require(composition.clips?.first)
        #expect(composition.duration_seconds == 5)
        #expect(clip.start_seconds == 4)
        #expect(clip.end_seconds == 5)

        let zeroDuration = SceneCompositionMapper.composition(from: [], duration: -2)
        #expect(zeroDuration.duration_seconds == 1)
    }

    @Test("Text cues preserve identity and text and are restored in time order")
    func textCueRoundTrip() {
        let later = SpatialTextCue(id: TestFixtures.textCueID, time: 8, text: "later")
        let earlier = SpatialTextCue(id: TestFixtures.phraseID, time: 2, text: "earlier")
        let composition = SceneCompositionMapper.composition(
            from: [],
            duration: 10,
            textCues: [later, earlier]
        )
        let restored = SceneCompositionMapper.textCues(from: composition)
        #expect(restored.map(\.id) == [earlier.id, later.id])
        #expect(restored.map(\.time) == [2, 8])
        #expect(restored.map(\.text) == ["earlier", "later"])
    }

    @Test("Version-two composition restores clip and source-group relationships")
    func versionTwoToEditorSources() throws {
        let original = [
            TestFixtures.editorSource(id: TestFixtures.firstClipID, start: 1, duration: 3),
            TestFixtures.editorSource(
                id: TestFixtures.secondClipID,
                start: 5,
                duration: 4,
                looping: false
            )
        ]
        let composition = SceneCompositionMapper.composition(from: original, duration: 12)
        let restored = SceneCompositionMapper.editorSources(from: composition)
        #expect(restored.count == 2)
        #expect(Set(restored.map(\.effectiveSourceGroupID)) == [TestFixtures.groupID])

        let first = try #require(restored.first { $0.id == TestFixtures.firstClipID })
        #expect(first.sourceGroupID == TestFixtures.groupID)
        #expect(first.audioStartTime == 1)
        #expect(first.audioEndTime == 4)
        #expect(first.sourceOffsetSeconds == 0.25)
        #expect(first.crossfadeMilliseconds == 900)
        #expect(first.fadeInMilliseconds == 100)
        #expect(first.fadeOutMilliseconds == 200)
    }

    @Test("Version-one composition migrates to editor sources")
    func versionOneMigration() throws {
        let track = APIContentDTO.CompositionTrack(
            id: TestFixtures.firstClipID,
            asset_id: TestFixtures.assetID,
            resource_key: "rain_soft",
            layer: AudioLayerKind.environment.rawValue,
            loop: true,
            start_seconds: 2,
            end_seconds: 7,
            source_duration_seconds: 5,
            keyframes: [
                APIContentDTO.CompositionKeyframe(t: 2, angle: .pi / 2, radius: 0.6)
            ]
        )
        let composition = APIContentDTO.SceneComposition(
            schema: "scene_composition_v1",
            version: 1,
            duration_seconds: 10,
            tracks: [track]
        )
        let source = try #require(SceneCompositionMapper.editorSources(from: composition).first)
        #expect(source.id == track.id)
        #expect(source.effectiveSourceGroupID == track.id)
        #expect(source.assetID == TestFixtures.assetID)
        #expect(source.resourceName == "rain_soft")
        #expect(source.isLooping == true)
        #expect(source.audioStartTime == 2)
        #expect(source.audioEndTime == 7)
        #expect(approximatelyEqual(source.defaultPosition, CGPoint(x: 0.6, y: 0)))
    }

    @Test("Known materials and unknown custom materials use stable resource keys")
    func resourceKeyMapping() {
        let known = TestFixtures.editorSource(
            materialID: "rain",
            assetID: nil,
            resourceName: nil
        )
        let unknown = TestFixtures.editorSource(
            materialID: "crickets_custom",
            assetID: nil,
            resourceName: nil
        )
        #expect(SceneCompositionMapper.resourceKey(for: known) == "rain_soft")
        #expect(SceneCompositionMapper.resourceKey(for: unknown) == "create_crickets_custom")
    }

    @Test("Unknown persisted resource keys restore with a safe group fallback")
    func unknownResourceFallback() throws {
        let group = APIContentDTO.CompositionSourceGroup(
            id: TestFixtures.groupID,
            name: "Unknown source",
            symbol_name: nil,
            layer: "future-layer",
            display_policy: nil,
            position_keyframes: []
        )
        let clip = APIContentDTO.CompositionClip(
            id: TestFixtures.firstClipID,
            source_group_id: group.id,
            asset_id: nil,
            resource_key: "future_resource",
            start_seconds: 0,
            end_seconds: 2,
            source_offset_seconds: nil,
            playback_mode: "oneshot",
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
            duration_seconds: 2,
            source_groups: [group],
            clips: [clip]
        )
        let restored = try #require(SceneCompositionMapper.editorSources(from: composition).first)
        #expect(restored.name == "Unknown source")
        #expect(restored.iconName == "waveform")
        #expect(restored.resourceName == "future_resource")
        #expect(restored.theme == .wind)
    }

    @Test("Composition JSON round trip preserves business fields")
    func jsonRoundTrip() throws {
        let source = TestFixtures.editorSource()
        let cues = [SpatialTextCue(id: TestFixtures.textCueID, time: 3, text: "breathe")]
        let original = SceneCompositionMapper.composition(
            from: [source],
            duration: 12,
            textCues: cues
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(APIContentDTO.SceneComposition.self, from: data)
        #expect(decoded.schema == original.schema)
        #expect(decoded.version == original.version)
        #expect(decoded.duration_seconds == original.duration_seconds)
        #expect(decoded.source_groups?.map(\.id) == original.source_groups?.map(\.id))
        #expect(decoded.clips?.map(\.id) == original.clips?.map(\.id))
        #expect(decoded.clips?.first?.resource_key == original.clips?.first?.resource_key)
        #expect(decoded.clips?.first?.playback_mode == original.clips?.first?.playback_mode)
        #expect(decoded.text_cues == original.text_cues)
    }
}
