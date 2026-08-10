# DreamWeaver iOS Automated Testing Report

## Verification Identity

- Date: 2026-08-10
- Git branch: `integration/frontend-backend`
- Production baseline commit: `ce94ba8d1ffda719f6a2c2923916eb2bfa5002d2`
- Production baseline subject: `ce94ba8 merge: sync creation controls and scene transitions`
- Automated-test implementation commit: `fd666d3d9a69a65fb5528350e34e3fe1330b2def`
- Automated-test implementation subject: `fd666d3 test: cover timeline scene plan compilation`
- Worktree before this task: clean
- macOS: 26.5.2 (25F84)
- Xcode: 26.6 (17F113)
- Swift: Apple Swift 6.3.3, project language mode Swift 5
- Simulator: iPhone 17 Pro, iOS 26.5 (23F77), arm64
- Simulator UDID: `8091EB6F-BD6E-477B-B764-C068EA70D091`

## Existing Product Acceptance

- Xcode acceptance: passed before this task.
- Real-device full functional acceptance: passed before this task.
- These two statements are the user-provided project baseline. The automated
  results below are additional reproducible engineering evidence and do not
  replace device-level listening, authentication, or interaction acceptance.

## Automated Test Result

- Framework: Apple Swift Testing (`import Testing`)
- Test target: `DreamWeaverTests`, hosted by `DreamWeaver`
- Shared scheme: `DreamWeaver`
- Baseline Debug app build: passed before test-target changes (approximately 6.5 seconds)
- Formal complete run 1: passed; 114 parameterized executions, 0 failed, 0 skipped
- Formal complete run 2: passed; 114 parameterized executions, 0 failed, 0 skipped
- Xcode result-summary count: 89 test identifiers in each run. Xcode separately
  reports 114 device-configuration passes because seven tests use dynamic parameters.
- Run 1 result duration: 15.087 seconds
- Run 2 result duration: 16.356 seconds
- Final Debug app build: passed
- Formal run 2 build-result diagnostics: 0 errors, 0 warnings
- Network dependency: none
- Account dependency: none
- Audio/video dependency: none
- Wall-clock or scheduling sleeps: none
- Result bundles: generated locally under `.build/TestResults` and intentionally ignored

The baseline and final app builds both displayed Xcode's existing informational
App Intents metadata warning because the app does not link `AppIntents.framework`.
No warning originates from the new test sources. The formal incremental test-run
build summary reports zero warnings.

## Coverage Scope

| Suite | Verified behavior | Result |
|---|---|---|
| `RadialGainCurveTests` | radius/gain/dB endpoints, clamp, monotonicity, inverse round trip, finite values | Passed |
| `SpatialTrajectoryEvaluatorTests` | position and automation interpolation, sorting, clamp, angle normalization and shortest path | Passed |
| `LoopCrossfadeControllerTests` | equal-power gains, progress clamp, duration validation/cap, resource presets | Passed |
| `SceneRenderPlanModelTests` | clip/group/plan invariants, stable clip ordering, event ordering and renderer version | Passed |
| `ScenePlanCompilerTests` | v1, v2, editor and Timeline inputs; repeat expansion, baseline normalization, same-time precedence, interrupted fades, group/clip separation, field retention, gap guards and events | Passed |
| `SpatialTrajectoryProcessingTests` | sparse/recorded evaluation, flattening, sorting/deduplication, time-aware simplification and slicing | Passed |
| `SceneCompositionMapperTests` | v2 serialization, v1 migration, polar mapping, timing clamps, text cues and JSON round trip | Passed |
| `SceneRendererStateTests` | deterministic load/seek/stop, half-open clip bounds, activity, trajectory, gain, automation and manual override | Passed |
| `BundledTimelineContractTests` | Hair Care v12 and Rain Eaves v11 formal JSON runtime contracts plus unknown-scene fallback | Passed |

Selected production-file line coverage from formal run 2:

| Production file | Line coverage |
|---|---:|
| `RadialGainCurve.swift` | 100.00% (11/11) |
| `LoopCrossfadeController.swift` | 100.00% (20/20) |
| `SceneRenderPlan.swift` | 100.00% (19/19) |
| `SceneSourceGroup.swift` | 100.00% (15/15) |
| `SceneAudioClip.swift` | 100.00% (18/18) |
| `SpatialTrajectoryEvaluator.swift` | 97.37% (74/76) |
| `LocalTimelineFixture.swift` | 82.46% (47/57) |
| `ScenePlanCompiler.swift` | 96.01% (650/677) |
| `SceneRenderer.swift` | 67.98% (121/178) |
| `SceneCompositionMapper.swift` | 82.48% (819/993) |
| `SpatialTimelineModels.swift` | 44.16% (291/659) |

The full app target reports 24.98% line coverage because this task intentionally
targets deterministic algorithms and contracts rather than SwiftUI rendering,
authentication, networking, or hardware audio behavior.

## Bundled Resource Contracts

- Hair Care (`hair_care_timeline_v11.json`): scene ID matches, runtime version 12,
  duration hint 620 seconds, 20 unique phrases, 138 cues, and 242 actions.
- Rain Eaves (`rain_eaves_timeline_v9.json`): scene ID matches, runtime version 11,
  duration hint 620 seconds, no phrases, 36 unique cues, and 75 actions.
- Unknown scene IDs preserve the requested ID and return the defined empty timeline.

## Reproduction Commands

```bash
xcodebuild -showdestinations \
  -project DreamWeaver.xcodeproj \
  -scheme DreamWeaver

xcodebuild build \
  -project DreamWeaver.xcodeproj \
  -scheme DreamWeaver \
  -configuration Debug \
  -destination 'platform=iOS Simulator,id=<SIMULATOR_UDID>' \
  -derivedDataPath "$PWD/.build/DerivedData"

xcodebuild test \
  -project DreamWeaver.xcodeproj \
  -scheme DreamWeaver \
  -configuration Debug \
  -destination 'platform=iOS Simulator,id=<SIMULATOR_UDID>' \
  -derivedDataPath "$PWD/.build/DerivedData" \
  -resultBundlePath "$PWD/.build/TestResults/DreamWeaverTests-<unique-run>.xcresult" \
  -enableCodeCoverage YES

xcrun xcresulttool get test-results summary \
  --path .build/TestResults/DreamWeaverTests-<unique-run>.xcresult

xcrun xccov view --report \
  .build/TestResults/DreamWeaverTests-<unique-run>.xcresult
```

Run the `xcodebuild test` command twice without changing sources and use a
different result-bundle name for each run.

## Production Changes

- None. No app Swift source, resource, deployment target, Team, bundle identifier,
  persistence format, audio behavior, visual behavior, network contract, login
  behavior, or user interaction was changed.
- The project file only adds the hosted unit-test target and its dependency.
- The shared app scheme only adds the test target to the Test action.

## Intentionally Device-Verified Scope

- HRTF perception and subjective spatial localization
- Audible loop-seam quality and headphone-dependent loudness
- Real `AVAudioEngine` and `AVAudioEnvironmentNode` hardware behavior
- Apple system UI, Sign in with Apple, microphone permissions, and real credentials
- Backend, object storage, account, and external-network integration
- Background/lock-screen audio and procedural visual comfort

## Repository Quality Checks

- `plutil -lint DreamWeaver.xcodeproj/project.pbxproj`: passed
- `git diff --check`: passed
- No production source files changed
- Only the automated-test source and this verification report changed in the
  review follow-up
- No `.xcresult`, DerivedData, `.xctest` binary, Simulator data, audio, or video is
  tracked or shown by `git status`
- `.build/` is ignored by the repository

## Flat Competition Submission Mapping

| Flat submission name | Repository path | Purpose |
|---|---|---|
| `18_IOS_TEST_TestFixtures.swift` | `DreamWeaverTests/TestFixtures.swift` | Stable IDs and in-memory fixtures |
| `18_IOS_TEST_TestSupport.swift` | `DreamWeaverTests/TestSupport.swift` | Floating-point and point comparisons |
| `18_IOS_TEST_RadialGainCurveTests.swift` | `DreamWeaverTests/RadialGainCurveTests.swift` | Radial loudness contract |
| `18_IOS_TEST_SpatialTrajectoryEvaluatorTests.swift` | `DreamWeaverTests/SpatialTrajectoryEvaluatorTests.swift` | Runtime interpolation and angle contract |
| `18_IOS_TEST_LoopCrossfadeControllerTests.swift` | `DreamWeaverTests/LoopCrossfadeControllerTests.swift` | Equal-power loop transition contract |
| `18_IOS_TEST_SceneRenderPlanModelTests.swift` | `DreamWeaverTests/SceneRenderPlanModelTests.swift` | Executable model invariants |
| `18_IOS_TEST_ScenePlanCompilerTests.swift` | `DreamWeaverTests/ScenePlanCompilerTests.swift` | v1/v2/editor compiler architecture |
| `18_IOS_TEST_SpatialTrajectoryProcessingTests.swift` | `DreamWeaverTests/SpatialTrajectoryProcessingTests.swift` | Create recording processing |
| `18_IOS_TEST_SceneCompositionMapperTests.swift` | `DreamWeaverTests/SceneCompositionMapperTests.swift` | Create composition serialization |
| `18_IOS_TEST_SceneRendererStateTests.swift` | `DreamWeaverTests/SceneRendererStateTests.swift` | Deterministic renderer state |
| `18_IOS_TEST_BundledTimelineContractTests.swift` | `DreamWeaverTests/BundledTimelineContractTests.swift` | Formal JSON resource contracts |
| `03_VERIFICATION_AND_SCOPE.md` | `docs/ios-automated-testing-report.md` | Reproducible verification evidence and scope |
