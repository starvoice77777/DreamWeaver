import Foundation

/// Pure loudness mapping used by the renderer, UI readouts, migration tooling,
/// and tests. AVFoundation is intentionally not imported here.
nonisolated enum RadialGainCurve {
    static let edgeGain = 0.01
    static let exponent = 3.0

    static func gain(forRadius radius: Double) -> Double {
        let r = min(max(radius, 0), 1)
        return edgeGain + (1 - edgeGain) * (1 - pow(r, exponent))
    }

    static func radius(forGain gain: Double) -> Double {
        let g = min(max(gain, edgeGain), 1)
        return pow((1 - g) / (1 - edgeGain), 1 / exponent)
    }

    static func decibels(forRadius radius: Double) -> Double {
        20 * log10(gain(forRadius: radius))
    }
}
