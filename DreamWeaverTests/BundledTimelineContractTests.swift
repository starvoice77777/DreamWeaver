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

    @Test("Rain v1.2 upgrades persisted personal-mix baselines")
    func rainPersistedMixUpgrade() throws {
        let scene = try #require(MockDataService.makeScenes().first { $0.id == DemoIDs.rainEavesScene })
        var persisted = scene.soundSources
        let legacyBaselines: [UUID: Double] = [
            DemoIDs.sourceRainSoftFar: 0.22,
            DemoIDs.sourceRain: 0,
            DemoIDs.sourceRainBambooLeaf: 0,
            DemoIDs.sourceWind: 0,
        ]
        for index in persisted.indices {
            persisted[index].initialEnvelope = legacyBaselines[persisted[index].id] ?? 0
            persisted[index].isEnabled = index.isMultiple(of: 2)
            persisted[index].position = SpatialPosition(
                angle: Double(index) * 0.2,
                radius: 0.3 + Double(index) * 0.1
            )
        }

        let upgraded = AppState.sourcesByRebindingOfficialMetadata(
            persisted,
            to: scene.soundSources
        )

        #expect(upgraded.count == persisted.count)
        for source in upgraded {
            let before = try #require(persisted.first { $0.id == source.id })
            #expect(source.initialEnvelope == 1)
            #expect(source.isEnabled == before.isEnabled)
            #expect(source.position == before.position)
        }
    }

    @Test("Fireplace review replaces only the local preset and compiles its authored intervals")
    func fireplaceReviewContract() throws {
        let scene = try #require(MockDataService.makeScenes().first { $0.id == DemoIDs.fireplaceScene })
        #if DEBUG
        #expect(scene.name == "炉边静夜")
        #expect(scene.soundSources.count == 5 && scene.isDemoPlayable)
        #expect(scene.soundSources.allSatisfy { $0.initialEnvelope == 1 && $0.assetId == nil })
        let timeline = LocalTimelineFixture.timeline(for: scene.id)
        #expect(timeline.version == 4 && timeline.duration_hint_seconds == 620)
        let plan = ScenePlanCompiler.compile(timeline: timeline, scene: scene)
        #expect(plan.clips.count == 7)
        #expect(plan.sourceGroups.count == 5)
        for (key, start, end, crossfade) in [
            ("handoff_room_quiet", 0.0, 620.0, 500),
            ("handoff_fire_soft_01", 10.0, 620.0, 1000)
        ] {
            let clip = try #require(plan.clips.first { $0.resourceKey == key })
            #expect(clip.startSeconds == start && clip.endSeconds == end)
            #expect(clip.playbackMode == .boundedLoop && clip.crossfadeMilliseconds == crossfade)
        }
        let triggers = plan.clips.filter { $0.playbackMode == .oneshot }.sorted { $0.startSeconds < $1.startSeconds }
        #expect(triggers.map(\.startSeconds) == [75, 168, 278, 389, 505])
        for (clip, end) in zip(triggers, [80.0, 172.696, 282.597, 394.0, 509.696]) {
            #expect(abs(clip.endSeconds - end) < 0.05)
            #expect(clip.crossfadeMilliseconds == 0)
            let key = try #require(clip.resourceKey)
            #expect(LocalPlaybackService.url(forResource: key) != nil)
        }
        let fire = try #require(scene.soundSources.first { $0.resourceName == "handoff_fire_soft_01" })
        let curve = try #require(plan.automationCurves.first { $0.target == .sourceGroup(fire.id) })
        for (time, gain) in [(10.0, 0.0), (25.0, 0.34), (590.0, 0.3), (620.0, 0.0)] {
            #expect(approximatelyEqual(SpatialTrajectoryEvaluator.automationValue(at: time, keyframes: curve.keyframes), gain))
        }
        #else
        #expect(HandoffSceneCatalog.timeline(for: scene.id) == nil)
        #expect(!scene.soundSources.contains { $0.resourceName?.hasPrefix("handoff_") == true })
        #endif
    }

    @Test("Mist review preserves moving water, long fades and all seven one-shots")
    func mistReviewContract() throws {
        let scene = try #require(MockDataService.makeScenes().first { $0.id == DemoIDs.mistTideScene })
        #if DEBUG
        #expect(scene.name == "雾海缓潮" && scene.soundSources.count == 6)
        #expect(scene.soundSources.allSatisfy { $0.initialEnvelope == 1 && $0.assetId == nil })
        #expect(scene.soundSources.map(\.layer) == [
            .environment, .environment, .ambience, .ambience, .trigger, .trigger
        ])
        let timeline = LocalTimelineFixture.timeline(for: scene.id)
        #expect(timeline.version == 4 && timeline.duration_hint_seconds == 600)
        let plan = ScenePlanCompiler.compile(timeline: timeline, scene: scene)
        #expect(plan.sourceGroups.count == 6 && plan.clips.count == 11)
        for (key, start, end, crossfade) in [
            ("handoff_ocean_bed_soft", 0.0, 600.0, 1200),
            ("handoff_sea_wind_soft", 0.0, 600.0, 500),
            ("handoff_shore_water_soft", 0.0, 330.0, 750),
            ("handoff_boat_water_lap", 300.0, 600.0, 750)
        ] {
            let clip = try #require(plan.clips.first { $0.resourceKey == key })
            #expect(clip.startSeconds == start && clip.endSeconds == end)
            #expect(clip.playbackMode == .boundedLoop && clip.crossfadeMilliseconds == crossfade)
            #expect(LocalPlaybackService.url(forResource: key) != nil)
        }
        let shots = plan.clips.filter { $0.playbackMode == .oneshot }.sorted { $0.startSeconds < $1.startSeconds }
        #expect(shots.map(\.startSeconds) == [105, 220, 335, 405, 465, 475, 535])
        #expect(shots.allSatisfy { abs($0.duration - 5) < 0.05 })
        for (key, gain) in [("handoff_shore_water_soft", 0.14), ("handoff_boat_water_lap", 0.15)] {
            let source = try #require(scene.soundSources.first { $0.resourceName == key })
            let curve = try #require(plan.automationCurves.first { $0.target == .sourceGroup(source.id) })
            #expect(approximatelyEqual(SpatialTrajectoryEvaluator.automationValue(at: 315, keyframes: curve.keyframes), gain))
        }
        let shore = try #require(scene.soundSources.first { $0.resourceName == "handoff_shore_water_soft" })
        let group = try #require(plan.sourceGroups.first { $0.id == shore.id })
        for (time, angle, radius) in [(0.0, -1.05, 0.92), (90.0, -0.65, 0.92),
                                     (180.0, -0.1, 0.93), (270.0, 0.5, 0.95), (330.0, 0.95, 0.98)] {
            let position = SpatialTrajectoryEvaluator.position(
                at: time, keyframes: group.positionKeyframes, defaultPosition: group.defaultPosition
            )
            #expect(approximatelyEqual(position.angle, angle))
            #expect(approximatelyEqual(position.radius, radius))
        }
        #else
        #expect(HandoffSceneCatalog.timeline(for: scene.id) == nil)
        #expect(!scene.soundSources.contains { $0.resourceName?.hasPrefix("handoff_") == true })
        #endif
    }

    @Test("Ear care review appends a serial moving-trigger preset")
    func earCareReviewContract() throws {
        #if DEBUG
        let scene = try #require(
            MockDataService.makeScenes().first { $0.id == HandoffSceneCatalog.earSceneID }
        )
        #expect(scene.name == "采耳 ASMR" && scene.soundSources.count == 6)
        #expect(scene.category == .whisper && scene.visualStyle == .emotionalFluid)
        #expect(scene.soundSources.map(\.layer) == [
            .environment, .trigger, .trigger, .trigger, .trigger, .trigger
        ])
        #expect(scene.soundSources.allSatisfy { source in
            source.initialEnvelope == 1
                && source.assetId == nil
                && source.resourceName.map { LocalPlaybackService.url(forResource: $0) != nil } == true
        })

        let timeline = try #require(HandoffSceneCatalog.timeline(for: scene.id))
        #expect(timeline.version == 4 && timeline.duration_hint_seconds == 600)
        #expect(timeline.cues.count == 48)
        #expect(timeline.cues.flatMap(\.actions).count == 244)

        let plan = ScenePlanCompiler.compile(timeline: timeline, scene: scene)
        #expect(plan.sourceGroups.count == 6 && plan.clips.count == 24)
        let bed = try #require(
            plan.clips.first { $0.resourceKey == "handoff_room_earcare_quiet_loop" }
        )
        #expect(bed.startSeconds == 0 && bed.endSeconds == 600)
        #expect(bed.playbackMode == .boundedLoop && bed.crossfadeMilliseconds == 500)

        let triggers = plan.clips
            .filter { $0.playbackMode == .oneshot }
            .sorted { $0.startSeconds < $1.startSeconds }
        #expect(triggers.count == 23)
        #expect(triggers.first?.startSeconds == 0 && triggers.last?.startSeconds == 580)
        #expect(zip(triggers, triggers.dropFirst()).allSatisfy { pair in
            abs(pair.0.endSeconds - pair.1.startSeconds) < 0.05
        })
        for (key, start, target) in [
            ("handoff_ear_cotton_swab_long", 0.0, 0.24),
            ("handoff_ear_goose_feather", 160.0, 0.3),
            ("handoff_ear_soft_brush", 180.0, 0.28),
            ("handoff_ear_sponge_press", 200.0, 0.26),
            ("handoff_ear_pick_soft", 220.0, 0.25),
        ] {
            let source = try #require(scene.soundSources.first { $0.resourceName == key })
            let curve = try #require(
                plan.automationCurves.first { $0.target == .sourceGroup(source.id) }
            )
            #expect(approximatelyEqual(
                SpatialTrajectoryEvaluator.automationValue(at: start, keyframes: curve.keyframes),
                0
            ))
            #expect(approximatelyEqual(
                SpatialTrajectoryEvaluator.automationValue(
                    at: start + 0.35, keyframes: curve.keyframes
                ),
                target
            ))
        }
        #else
        #expect(HandoffSceneCatalog.timeline(for: HandoffSceneCatalog.earSceneID) == nil)
        #expect(!MockDataService.makeScenes().contains { $0.id == HandoffSceneCatalog.earSceneID })
        #endif
    }

    @Test("Page-turning review appends serial reading details over three stable beds")
    func pageTurningReviewContract() throws {
        #if DEBUG
        let scene = try #require(
            MockDataService.makeScenes().first { $0.id == HandoffSceneCatalog.pageSceneID }
        )
        #expect(scene.name == "翻页入眠" && scene.soundSources.count == 11)
        #expect(scene.category == .whisper && scene.visualStyle == .snowStudy)
        #expect(scene.soundSources.map(\.layer) == [
            .environment, .ambience, .ambience,
            .trigger, .trigger, .trigger, .trigger,
            .trigger, .trigger, .trigger, .trigger
        ])
        #expect(scene.soundSources.allSatisfy { source in
            source.initialEnvelope == 1
                && source.assetId == nil
                && source.resourceName.map { LocalPlaybackService.url(forResource: $0) != nil } == true
        })

        let timeline = try #require(HandoffSceneCatalog.timeline(for: scene.id))
        #expect(timeline.version == 4 && timeline.duration_hint_seconds == 250)
        #expect(timeline.cues.count == 100)
        #expect(timeline.cues.flatMap(\.actions).count == 355)

        let plan = ScenePlanCompiler.compile(timeline: timeline, scene: scene)
        #expect(plan.sourceGroups.count == 11 && plan.clips.count == 35)
        let beds = plan.clips.filter { $0.playbackMode == .boundedLoop }
        #expect(beds.count == 3)
        #expect(beds.allSatisfy { clip in
            clip.startSeconds == 0
                && clip.endSeconds == 250
                && clip.crossfadeMilliseconds == 500
        })

        let triggers = plan.clips
            .filter { $0.playbackMode == .oneshot }
            .sorted { $0.startSeconds < $1.startSeconds }
        #expect(triggers.count == 32)
        #expect(triggers.first?.startSeconds == 15 && triggers.last?.startSeconds == 238.26)
        #expect(zip(triggers, triggers.dropFirst()).allSatisfy { pair in
            pair.0.endSeconds <= pair.1.startSeconds
        })
        for (key, target) in [
            ("handoff_page_turn_slow_a", 0.18),
            ("handoff_pencil_write_soft_a", 0.16),
            ("handoff_cloth_soft_a", 0.16),
            ("handoff_page_turn_slow_b", 0.18),
            ("handoff_pencil_write_soft_b", 0.16),
            ("handoff_cloth_soft_b", 0.16),
            ("handoff_water_sip_soft", 0.11),
            ("handoff_cookie_chew_optional", 0.08),
        ] {
            let source = try #require(scene.soundSources.first { $0.resourceName == key })
            let first = try #require(triggers.first { $0.resourceKey == key })
            let curve = try #require(
                plan.automationCurves.first { $0.target == .sourceGroup(source.id) }
            )
            #expect(approximatelyEqual(
                SpatialTrajectoryEvaluator.automationValue(
                    at: first.startSeconds, keyframes: curve.keyframes
                ),
                0
            ))
            #expect(approximatelyEqual(
                SpatialTrajectoryEvaluator.automationValue(
                    at: first.startSeconds + 0.35, keyframes: curve.keyframes
                ),
                target
            ))
        }
        #else
        #expect(HandoffSceneCatalog.timeline(for: HandoffSceneCatalog.pageSceneID) == nil)
        #expect(!MockDataService.makeScenes().contains { $0.id == HandoffSceneCatalog.pageSceneID })
        #endif
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
