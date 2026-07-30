import Foundation
import CoreGraphics

struct SpatialPosition: Hashable, Codable, Equatable {
    /// Angle in radians around the listener (0 = right, π/2 = top).
    var angle: Double
    /// Normalized distance from center, 0.2...0.95.
    var radius: Double

    static let `default` = SpatialPosition(angle: 0, radius: 0.55)

    var distanceLabel: DistanceLabel {
        DistanceLabel.from(radius: radius)
    }

    func point(in size: CGSize, centerScale: CGFloat = 0.42) -> CGPoint {
        let maxR = min(size.width, size.height) * centerScale
        let r = CGFloat(radius) * maxR
        return CGPoint(
            x: size.width / 2 + cos(angle) * r,
            y: size.height / 2 - sin(angle) * r
        )
    }

    static func from(point: CGPoint, in size: CGSize, centerScale: CGFloat = 0.42) -> SpatialPosition {
        let dx = point.x - size.width / 2
        let dy = size.height / 2 - point.y
        let maxR = min(size.width, size.height) * centerScale
        let raw = hypot(dx, dy) / max(maxR, 1)
        let radius = min(max(Double(raw), 0.22), 0.95)
        let angle = atan2(Double(dy), Double(dx))
        return SpatialPosition(angle: angle, radius: radius)
    }
}
