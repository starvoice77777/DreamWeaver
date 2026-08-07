import Foundation

nonisolated enum LoopCrossfadeController {
    nonisolated struct Gains: Equatable, Sendable {
        let outgoing: Float
        let incoming: Float
    }

    /// Equal-power weights. The sum of squared gains remains one throughout
    /// the overlap and this internal A/B transition never changes group radius.
    static func gains(at progress: Double) -> Gains {
        let t = min(max(progress, 0), 1)
        return Gains(
            outgoing: Float(cos(t * Double.pi / 2)),
            incoming: Float(sin(t * Double.pi / 2))
        )
    }

    static func validatedDuration(
        milliseconds: Int,
        sourceDurationSeconds: Double
    ) -> TimeInterval {
        guard milliseconds > 0, sourceDurationSeconds > 0 else { return 0 }
        return min(Double(milliseconds) / 1000, sourceDurationSeconds * 0.49)
    }

    /// Delivery-package loop requirements. Timeline v1 does not expose these
    /// fields, so the compiler restores them by stable resource key.
    static func preferredMilliseconds(for resourceKey: String?) -> Int {
        switch resourceKey {
        case "rain_soft": return 1000
        case "rain_parasol", "hair_wash_water_cycle", "hair_wash_foam_rub",
             "hair_wash_scalp_foam", "hair_wash_finger_massage": return 1200
        case "rain_bamboo_leaf": return 800
        default: return 0
        }
    }
}
