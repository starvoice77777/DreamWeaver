import CoreGraphics
import Foundation

nonisolated func approximatelyEqual(
    _ lhs: Double,
    _ rhs: Double,
    tolerance: Double = 1e-8
) -> Bool {
    abs(lhs - rhs) <= tolerance
}
nonisolated func approximatelyEqual(
    _ lhs: Float,
    _ rhs: Float,
    tolerance: Float = 1e-5
) -> Bool {
    abs(lhs - rhs) <= tolerance
}

nonisolated func approximatelyEqual(
    _ lhs: CGFloat,
    _ rhs: CGFloat,
    tolerance: CGFloat = 1e-6
) -> Bool {
    abs(lhs - rhs) <= tolerance
}

nonisolated func approximatelyEqual(
    _ lhs: CGPoint,
    _ rhs: CGPoint,
    tolerance: CGFloat = 1e-6
) -> Bool {
    approximatelyEqual(lhs.x, rhs.x, tolerance: tolerance)
        && approximatelyEqual(lhs.y, rhs.y, tolerance: tolerance)
}
