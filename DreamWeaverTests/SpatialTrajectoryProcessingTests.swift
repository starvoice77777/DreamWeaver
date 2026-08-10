import CoreGraphics
import Foundation
import Testing
@testable import DreamWeaver

@Suite("Create spatial trajectory processing")
struct SpatialTrajectoryProcessingTests {
    private func point(
        _ time: Double,
        _ x: CGFloat,
        _ y: CGFloat = 0,
        interpolation: SceneInterpolationMode? = nil
    ) -> SpatialKeyPoint {
        SpatialKeyPoint(
            id: UUID(uuidString: String(
                format: "81000000-0000-4000-8000-%012d",
                Int((time * 1_000).rounded()) + 1
            ))!,
            time: time,
            position: CGPoint(x: x, y: y),
            interpolation: interpolation
        )
    }

    private func sample(_ time: Double, _ x: CGFloat, _ y: CGFloat = 0) -> SpatialMotionSample {
        SpatialMotionSample(
            id: UUID(uuidString: String(
                format: "82000000-0000-4000-8000-%012d",
                Int((time * 1_000).rounded()) + 1
            ))!,
            time: time,
            position: CGPoint(x: x, y: y)
        )
    }

    @Test("Sparse keypoints support linear, smoothstep, and hold segments")
    func sparseInterpolationModes() {
        let linear = SpatialTrajectory.position(
            at: 2.5,
            keyPoints: [point(0, 0, interpolation: .linear), point(10, 1)],
            defaultPosition: .zero
        )
        let smooth = SpatialTrajectory.position(
            at: 2.5,
            keyPoints: [point(0, 0, interpolation: .smoothstep), point(10, 1)],
            defaultPosition: .zero
        )
        let hold = SpatialTrajectory.position(
            at: 9,
            keyPoints: [point(0, 0.2, interpolation: .hold), point(10, 0.8)],
            defaultPosition: .zero
        )
        #expect(approximatelyEqual(linear.x, 0.25))
        #expect(approximatelyEqual(smooth.x, 0.15625))
        #expect(approximatelyEqual(hold.x, 0.2))
    }

    @Test("Recorded samples always interpolate linearly")
    func recordedSamplesAreLinear() {
        let result = SpatialTrajectory.position(
            at: 2.5,
            samples: [sample(0, 0), sample(10, 1)],
            defaultPosition: .zero
        )
        #expect(approximatelyEqual(result.x, 0.25))
    }

    @Test("A recording clip takes precedence over manual keypoints in its range")
    func recordingPrecedence() {
        let source = TestFixtures.editorSource(
            keyPoints: [point(0, 0), point(10, 1)]
        )
        var recorded = source
        recorded.motionClips = [SpatialMotionClip(samples: [sample(4, -0.8), sample(6, -0.4)])]
        let result = SpatialTrajectory.position(at: 5, source: recorded)
        #expect(approximatelyEqual(result.x, -0.6))
    }

    @Test("Flattening removes covered manual points and marks recorded points")
    func flattenRecording() {
        var source = TestFixtures.editorSource(
            keyPoints: [point(0, 0), point(5, 0.5), point(10, 1)]
        )
        source.motionClips = [SpatialMotionClip(samples: [sample(4, -0.4), sample(6, -0.6)])]
        let flattened = SpatialTrajectory.flattenedKeyPoints(for: source)
        #expect(flattened.map(\.time) == [0, 4, 6, 10])
        #expect(flattened.filter { $0.time == 4 || $0.time == 6 }.allSatisfy {
            $0.interpolation == .recordedLinear && !$0.createdByUser
        })
    }

    @Test("Raw recording samples are sorted and near-duplicate times use the later sample")
    func recordingOrderingAndDeduplication() {
        let processed = SpatialTrajectory.processedRecordingSamples([
            sample(0.02, 0.2),
            sample(0, 0),
            sample(0.005, 0.1)
        ])
        #expect(processed.map(\.time) == [0.005, 0.02])
        #expect(approximatelyEqual(processed[0].position.x, 0.1))
    }

    @Test("Simplification preserves the first and last recording samples")
    func simplificationPreservesEndpoints() {
        let raw = (0..<20).map { sample(Double($0), CGFloat($0) / 25) }
        let processed = SpatialTrajectory.processedRecordingSamples(raw)
        #expect(processed.first?.id == raw.first?.id)
        #expect(processed.last?.id == raw.last?.id)
    }

    @Test("A nearly straight time-linear path simplifies to endpoints")
    func straightPathSimplification() {
        let raw = (0..<100).map { index in
            sample(Double(index) / 20, CGFloat(index) / 100)
        }
        let processed = SpatialTrajectory.processedRecordingSamples(raw, tolerance: 0.001)
        #expect(processed.count == 2)
    }

    @Test("Time-aware simplification retains a pause on a straight path")
    func timeAwarePauseRetention() {
        let raw = [
            sample(0, 0),
            sample(1, 0.5),
            sample(9, 0.5),
            sample(10, 1)
        ]
        let processed = SpatialTrajectory.processedRecordingSamples(raw, tolerance: 0.01)
        #expect(processed.count > 2)
    }

    @Test("Processed recordings obey their maximum count")
    func maximumCount() {
        let raw = (0..<80).map { index in
            sample(
                Double(index) / 20,
                CGFloat(index) / 100,
                index.isMultiple(of: 2) ? 0.2 : -0.2
            )
        }
        let processed = SpatialTrajectory.processedRecordingSamples(
            raw,
            tolerance: 0.0001,
            maximumCount: 12
        )
        #expect(processed.count <= 12)
    }

    @Test("Slicing interpolates and preserves both requested boundaries")
    func sliceBoundaries() throws {
        let clip = SpatialMotionClip(samples: [sample(0, 0), sample(10, 1)])
        let sliced = try #require(SpatialTrajectory.sliced(clip, from: 2, through: 8))
        #expect(sliced.startTime == 2)
        #expect(sliced.endTime == 8)
        #expect(approximatelyEqual(sliced.samples.first!.position.x, 0.2))
        #expect(approximatelyEqual(sliced.samples.last!.position.x, 0.8))
    }

    @Test("Slices shorter than fifty milliseconds are rejected")
    func tinySlice() {
        let clip = SpatialMotionClip(samples: [sample(0, 0), sample(1, 1)])
        #expect(SpatialTrajectory.sliced(clip, from: 0.2, through: 0.249) == nil)
    }

    @Test("Points outside the unit circle are projected onto its edge")
    func unitCircleProjection() {
        let projected = SpatialTrajectory.clampedToUnitCircle(CGPoint(x: 3, y: 4))
        #expect(approximatelyEqual(projected.x, 0.6))
        #expect(approximatelyEqual(projected.y, 0.8))
        #expect(approximatelyEqual(hypot(projected.x, projected.y), 1))
    }

    @Test("Neighbor lookup handles before, exact-middle, and after times")
    func neighboringPoints() {
        let points = [point(0, 0), point(5, 0.5), point(10, 1)]
        let before = SpatialTrajectory.neighboringPoints(at: -1, keyPoints: points)
        #expect(before.previous == nil)
        #expect(before.next?.time == 0)

        let middle = SpatialTrajectory.neighboringPoints(at: 5, keyPoints: points)
        #expect(middle.previous?.time == 5)
        #expect(middle.next?.time == 10)

        let after = SpatialTrajectory.neighboringPoints(at: 11, keyPoints: points)
        #expect(after.previous?.time == 10)
        #expect(after.next == nil)
    }
}
