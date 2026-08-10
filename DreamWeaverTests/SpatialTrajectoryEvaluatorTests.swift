import Foundation
import Testing
@testable import DreamWeaver

@Suite("Spatial trajectory evaluator")
struct SpatialTrajectoryEvaluatorTests {
    private func positionFrame(
        time: Double,
        angle: Double,
        radius: Double,
        interpolation: SceneInterpolationMode = .linear
    ) -> ScenePositionKeyframe {
        ScenePositionKeyframe(
            time: time,
            position: SpatialPosition(angle: angle, radius: radius),
            interpolation: interpolation
        )
    }

    private func automationFrame(
        time: Double,
        value: Double,
        interpolation: SceneInterpolationMode = .linear
    ) -> SceneAutomationKeyframe {
        SceneAutomationKeyframe(time: time, value: value, interpolation: interpolation)
    }

    @Test("Empty position keyframes return a clamped default")
    func emptyPositionFrames() {
        let result = SpatialTrajectoryEvaluator.position(
            at: 4,
            keyframes: [],
            defaultPosition: SpatialPosition(angle: 3 * .pi, radius: 2)
        )
        #expect(approximatelyEqual(result.angle, .pi))
        #expect(approximatelyEqual(result.radius, 1))
    }

    @Test("A single position keyframe is returned and clamped")
    func singlePositionFrame() {
        let result = SpatialTrajectoryEvaluator.position(
            at: 100,
            keyframes: [positionFrame(time: 4, angle: -3 * .pi, radius: -1)],
            defaultPosition: .default
        )
        #expect(approximatelyEqual(result.angle, .pi))
        #expect(approximatelyEqual(result.radius, 0))
    }

    @Test("Unsorted position keyframes are evaluated in time order")
    func unsortedPositionFrames() {
        let result = SpatialTrajectoryEvaluator.position(
            at: 5,
            keyframes: [
                positionFrame(time: 10, angle: 1, radius: 1),
                positionFrame(time: 0, angle: 0, radius: 0)
            ],
            defaultPosition: .default
        )
        #expect(approximatelyEqual(result.angle, 0.5))
        #expect(approximatelyEqual(result.radius, 0.5))
    }

    @Test("Times outside the position curve use its endpoints")
    func positionEndpoints() {
        let frames = [
            positionFrame(time: 2, angle: -0.5, radius: 0.2),
            positionFrame(time: 8, angle: 0.5, radius: 0.8)
        ]
        #expect(SpatialTrajectoryEvaluator.position(
            at: -20,
            keyframes: frames,
            defaultPosition: .default
        ) == frames[0].position)
        #expect(SpatialTrajectoryEvaluator.position(
            at: 20,
            keyframes: frames,
            defaultPosition: .default
        ) == frames[1].position)
    }

    @Test(
        "Linear and recorded-linear position segments interpolate linearly",
        arguments: [SceneInterpolationMode.linear, .recordedLinear]
    )
    func linearPositionInterpolation(mode: SceneInterpolationMode) {
        let result = SpatialTrajectoryEvaluator.position(
            at: 5,
            keyframes: [
                positionFrame(time: 0, angle: 0, radius: 0.2, interpolation: mode),
                positionFrame(time: 10, angle: 1, radius: 0.8)
            ],
            defaultPosition: .default
        )
        #expect(approximatelyEqual(result.angle, 0.5))
        #expect(approximatelyEqual(result.radius, 0.5))
    }

    @Test("Smoothstep position interpolation uses the cubic easing function")
    func smoothstepPositionInterpolation() {
        let result = SpatialTrajectoryEvaluator.position(
            at: 2.5,
            keyframes: [
                positionFrame(time: 0, angle: 0, radius: 0, interpolation: .smoothstep),
                positionFrame(time: 10, angle: 1, radius: 1)
            ],
            defaultPosition: .default
        )
        #expect(approximatelyEqual(result.angle, 0.15625))
        #expect(approximatelyEqual(result.radius, 0.15625))
    }

    @Test("Hold position interpolation retains the lower value")
    func holdPositionInterpolation() {
        let result = SpatialTrajectoryEvaluator.position(
            at: 9.999,
            keyframes: [
                positionFrame(time: 0, angle: 0.2, radius: 0.3, interpolation: .hold),
                positionFrame(time: 10, angle: 0.8, radius: 0.9)
            ],
            defaultPosition: .default
        )
        #expect(approximatelyEqual(result.angle, 0.2))
        #expect(approximatelyEqual(result.radius, 0.3))
    }

    @Test("Position radii are clamped after interpolation")
    func positionRadiusIsClamped() {
        let below = SpatialTrajectoryEvaluator.position(
            at: 0,
            keyframes: [positionFrame(time: 0, angle: 0, radius: -2)],
            defaultPosition: .default
        )
        let above = SpatialTrajectoryEvaluator.position(
            at: 0,
            keyframes: [positionFrame(time: 0, angle: 0, radius: 2)],
            defaultPosition: .default
        )
        #expect(below.radius == 0)
        #expect(above.radius == 1)
    }

    @Test("Position interpolation takes the shortest path across the angle seam")
    func shortestAnglePath() {
        let start = 179.0 * Double.pi / 180
        let end = -179.0 * Double.pi / 180
        let result = SpatialTrajectoryEvaluator.position(
            at: 0.5,
            keyframes: [
                positionFrame(time: 0, angle: start, radius: 0.5),
                positionFrame(time: 1, angle: end, radius: 0.5)
            ],
            defaultPosition: .default
        )
        #expect(approximatelyEqual(abs(result.angle), .pi, tolerance: 1e-10))
        #expect(approximatelyEqual(
            SpatialTrajectoryEvaluator.shortestAngleDelta(from: start, to: end),
            2 * .pi / 180,
            tolerance: 1e-10
        ))
    }

    @Test(
        "Normalized angles remain in the open-left closed-right interval",
        arguments: [-12 * Double.pi, -3 * .pi, -.pi, 0, .pi, 3 * .pi, 12 * .pi]
    )
    func normalizedAngleRange(angle: Double) {
        let normalized = SpatialTrajectoryEvaluator.normalizedAngle(angle)
        #expect(normalized > -.pi)
        #expect(normalized <= .pi)
    }

    @Test("Exact position keyframe time returns that keyframe")
    func exactPositionKeyframe() {
        let expected = SpatialPosition(angle: 0.7, radius: 0.4)
        let result = SpatialTrajectoryEvaluator.position(
            at: 5,
            keyframes: [
                positionFrame(time: 0, angle: 0, radius: 0),
                ScenePositionKeyframe(time: 5, position: expected),
                positionFrame(time: 10, angle: 1, radius: 1)
            ],
            defaultPosition: .default
        )
        #expect(result == expected)
    }

    @Test("Near-identical position times remain finite")
    func tinyPositionInterval() {
        let result = SpatialTrajectoryEvaluator.position(
            at: 1.000_000_000_000_5,
            keyframes: [
                positionFrame(time: 1, angle: 0, radius: 0),
                positionFrame(time: 1.000_000_000_001, angle: 1, radius: 1)
            ],
            defaultPosition: .default
        )
        #expect(result.angle.isFinite)
        #expect(result.radius.isFinite)
    }

    @Test("Empty automation keyframes return the supplied default")
    func emptyAutomationFrames() {
        #expect(SpatialTrajectoryEvaluator.automationValue(
            at: 1,
            keyframes: [],
            defaultValue: 1.25
        ) == 1.25)
    }

    @Test("Automation endpoints and a single point are deterministic")
    func automationEndpoints() {
        let single = [automationFrame(time: 4, value: 1.5)]
        #expect(SpatialTrajectoryEvaluator.automationValue(at: 100, keyframes: single) == 1.5)

        let frames = [
            automationFrame(time: 2, value: 0.2),
            automationFrame(time: 8, value: 0.8)
        ]
        #expect(SpatialTrajectoryEvaluator.automationValue(at: -10, keyframes: frames) == 0.2)
        #expect(SpatialTrajectoryEvaluator.automationValue(at: 10, keyframes: frames) == 0.8)
    }

    @Test(
        "Linear automation modes interpolate linearly",
        arguments: [SceneInterpolationMode.linear, .recordedLinear]
    )
    func linearAutomationInterpolation(mode: SceneInterpolationMode) {
        let value = SpatialTrajectoryEvaluator.automationValue(
            at: 5,
            keyframes: [
                automationFrame(time: 0, value: 0, interpolation: mode),
                automationFrame(time: 10, value: 2)
            ]
        )
        #expect(approximatelyEqual(value, 1))
    }

    @Test("Smoothstep and hold automation preserve their authored semantics")
    func nonlinearAutomationInterpolation() {
        let smooth = [
            automationFrame(time: 0, value: 0, interpolation: .smoothstep),
            automationFrame(time: 10, value: 1)
        ]
        #expect(approximatelyEqual(
            SpatialTrajectoryEvaluator.automationValue(at: 2.5, keyframes: smooth),
            0.15625
        ))

        let hold = [
            automationFrame(time: 0, value: 0.3, interpolation: .hold),
            automationFrame(time: 10, value: 0.9)
        ]
        #expect(SpatialTrajectoryEvaluator.automationValue(at: 9, keyframes: hold) == 0.3)
    }

    @Test("Unsorted automation keyframes are evaluated in time order without clamping values")
    func unsortedAutomationFrames() {
        let value = SpatialTrajectoryEvaluator.automationValue(
            at: 5,
            keyframes: [
                automationFrame(time: 10, value: 2),
                automationFrame(time: 0, value: 1)
            ]
        )
        #expect(approximatelyEqual(value, 1.5))
    }
}
