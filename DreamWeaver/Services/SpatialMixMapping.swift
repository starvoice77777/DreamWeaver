import Foundation

/// Maps mix-board polar coordinates to stereo playback gains.
///
/// The board is treated as a **listener-ear-height** plane (no elevation):
/// - Angle 0 = right, π/2 = front (screen up), π = left, −π/2 = behind.
/// - Radius is perceived distance (near center = closer / louder).
///
/// We intentionally avoid hard L/R mute (`AVAudioPlayerNode.pan` at ±1).
/// Real sources at 90° still reach the far ear; ILD is a moderate bias only.
enum SpatialMixMapping {
    /// Board radius clamp (must match `SpatialPosition.from`).
    static let minRadius = 0.22
    static let maxRadius = 0.95

    /// Soft ILD for `AVAudioPlayerNode.pan` (−1…1). Opposite ear stays audible.
    static func playbackPan(from position: SpatialPosition) -> Float {
        // Lateral axis only: front/back (sin) stays centered — matches ear-height plane.
        let lateral = cos(position.angle) // −1 left … +1 right

        // Near the hole around the listener, shrink max pan so crossing the center
        // does not flip from “only left” to “only right”.
        let t = radiusNormalized(position.radius)
        // Stronger bias than v1 so azimuth is clearer, still below hard ±1 mute.
        let maxPan = 0.42 + 0.36 * t // ~0.42 near … ~0.78 far

        let shaped = tanh(lateral * 1.2) / tanh(1.2)
        return Float(max(-1, min(1, shaped * maxPan)))
    }

    /// Mix loudness from radius ≈ inverse-square (intensity ∝ 1/r²).
    /// Edge of the board approaches inaudible.
    static func mixVolume(fromRadius radius: Double) -> Double {
        let t = radiusNormalized(radius)
        // Near d=1 → gain 1; far d≈5 → gain 1/25 ≈ 0.04 before floor.
        let distance = 1.0 + 4.0 * t
        let raw = 1.0 / (distance * distance)
        return min(max(raw, 0.02), 1.0)
    }

    private static func radiusNormalized(_ radius: Double) -> Double {
        let span = maxRadius - minRadius
        guard span > 0 else { return 0 }
        return min(max((radius - minRadius) / span, 0), 1)
    }
}
