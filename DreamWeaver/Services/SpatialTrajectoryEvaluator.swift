import Foundation

nonisolated enum SpatialTrajectoryEvaluator {
    static func position(
        at time: Double,
        keyframes: [ScenePositionKeyframe],
        defaultPosition: SpatialPosition
    ) -> SpatialPosition {
        let points = keyframes.sorted { $0.time < $1.time }
        guard let first = points.first else { return clamped(defaultPosition) }
        guard points.count > 1, let last = points.last else { return clamped(first.position) }
        if time <= first.time { return clamped(first.position) }
        if time >= last.time { return clamped(last.position) }

        guard let upperIndex = points.firstIndex(where: { $0.time >= time }), upperIndex > 0 else {
            return clamped(first.position)
        }
        let lower = points[upperIndex - 1]
        let upper = points[upperIndex]
        let duration = max(upper.time - lower.time, 0.000_001)
        let raw = min(max((time - lower.time) / duration, 0), 1)
        let progress: Double
        switch lower.interpolation {
        case .linear, .recordedLinear:
            progress = raw
        case .smoothstep:
            progress = raw * raw * (3 - 2 * raw)
        case .hold:
            progress = raw < 1 ? 0 : 1
        }

        let delta = shortestAngleDelta(from: lower.position.angle, to: upper.position.angle)
        return clamped(
            SpatialPosition(
                angle: normalizedAngle(lower.position.angle + delta * progress),
                radius: lower.position.radius
                    + (upper.position.radius - lower.position.radius) * progress
            )
        )
    }

    static func automationValue(
        at time: Double,
        keyframes: [SceneAutomationKeyframe],
        defaultValue: Double = 1
    ) -> Double {
        let points = keyframes.sorted { $0.time < $1.time }
        guard let first = points.first else { return defaultValue }
        guard points.count > 1, let last = points.last else { return first.value }
        if time <= first.time { return first.value }
        if time >= last.time { return last.value }
        guard let upperIndex = points.firstIndex(where: { $0.time >= time }), upperIndex > 0 else {
            return first.value
        }
        let lower = points[upperIndex - 1]
        let upper = points[upperIndex]
        let duration = max(upper.time - lower.time, 0.000_001)
        let raw = min(max((time - lower.time) / duration, 0), 1)
        let progress: Double
        switch lower.interpolation {
        case .smoothstep:
            progress = raw * raw * (3 - 2 * raw)
        case .hold:
            progress = raw < 1 ? 0 : 1
        case .linear, .recordedLinear:
            progress = raw
        }
        return lower.value + (upper.value - lower.value) * progress
    }

    static func shortestAngleDelta(from start: Double, to end: Double) -> Double {
        normalizedAngle(end - start)
    }

    static func normalizedAngle(_ angle: Double) -> Double {
        var value = angle.truncatingRemainder(dividingBy: 2 * Double.pi)
        if value > Double.pi { value -= 2 * Double.pi }
        if value <= -Double.pi { value += 2 * Double.pi }
        return value
    }

    private static func clamped(_ position: SpatialPosition) -> SpatialPosition {
        SpatialPosition(
            angle: normalizedAngle(position.angle),
            radius: min(max(position.radius, 0), 1)
        )
    }
}
