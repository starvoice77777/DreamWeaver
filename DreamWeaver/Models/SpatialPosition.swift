import Foundation
import CoreGraphics

nonisolated struct SpatialPosition: Hashable, Codable, Equatable, Sendable {
    /// Angle in radians: 0 = front / screen-up, π/2 = right, -π/2 = left.
    var angle: Double
    /// Normalized distance from listener, ``SpatialMixMapping.minRadius``...``SpatialMixMapping.maxRadius``.
    /// Mapped directly to deterministic loudness (see `SpatialMixMapping.gain`).
    var radius: Double

    static let `default` = SpatialPosition(angle: 0, radius: 0.55)

    var distanceLabel: DistanceLabel {
        DistanceLabel.from(radius: radius)
    }

    func point(in size: CGSize, centerScale: CGFloat = 0.42) -> CGPoint {
        let maxR = min(size.width, size.height) * centerScale
        let r = CGFloat(radius) * maxR
        return CGPoint(
            x: size.width / 2 + sin(angle) * r,
            y: size.height / 2 - cos(angle) * r
        )
    }

    static func from(point: CGPoint, in size: CGSize, centerScale: CGFloat = 0.42) -> SpatialPosition {
        let dx = point.x - size.width / 2
        let dy = point.y - size.height / 2
        let maxR = min(size.width, size.height) * centerScale
        let raw = hypot(dx, dy) / max(maxR, 1)
        let radius = min(max(Double(raw), SpatialMixMapping.minRadius), SpatialMixMapping.maxRadius)
        let angle = atan2(Double(dx), -Double(dy))
        return SpatialPosition(angle: angle, radius: radius)
    }
}
