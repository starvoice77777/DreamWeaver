import Foundation
import Testing
@testable import DreamWeaver

@Suite("Radial gain curve")
struct RadialGainCurveTests {
    @Test("Center radius maps to unity gain")
    func centerGain() {
        #expect(approximatelyEqual(RadialGainCurve.gain(forRadius: 0), 1))
    }

    @Test("Edge radius maps to the configured floor")
    func edgeGain() {
        #expect(approximatelyEqual(RadialGainCurve.gain(forRadius: 1), 0.01))
    }

    @Test("Radius is clamped below the valid range")
    func negativeRadiusIsClamped() {
        #expect(approximatelyEqual(RadialGainCurve.gain(forRadius: -4), 1))
    }

    @Test("Radius is clamped above the valid range")
    func oversizedRadiusIsClamped() {
        #expect(approximatelyEqual(RadialGainCurve.gain(forRadius: 4), 0.01))
    }

    @Test("Center and edge decibels match the loudness contract")
    func decibelEndpoints() {
        #expect(approximatelyEqual(RadialGainCurve.decibels(forRadius: 0), 0))
        #expect(approximatelyEqual(RadialGainCurve.decibels(forRadius: 1), -40))
    }

    @Test("Gain decreases monotonically as radius increases")
    func gainIsMonotonic() {
        let gains = stride(from: 0.0, through: 1.0, by: 0.01).map {
            RadialGainCurve.gain(forRadius: $0)
        }
        #expect(zip(gains, gains.dropFirst()).allSatisfy { $0 >= $1 })
    }

    @Test(
        "Radius survives gain round trip",
        arguments: [0.0, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 1.0]
    )
    func radiusRoundTrip(radius: Double) {
        let gain = RadialGainCurve.gain(forRadius: radius)
        #expect(approximatelyEqual(RadialGainCurve.radius(forGain: gain), radius))
    }

    @Test("Inverse mapping clamps gains below the edge floor")
    func inverseClampsSmallGain() {
        #expect(approximatelyEqual(RadialGainCurve.radius(forGain: -2), 1))
        #expect(approximatelyEqual(RadialGainCurve.radius(forGain: 0.001), 1))
    }

    @Test("Inverse mapping clamps gains above unity")
    func inverseClampsLargeGain() {
        #expect(approximatelyEqual(RadialGainCurve.radius(forGain: 2), 0))
    }

    @Test("Valid inputs always produce finite values")
    func validInputsAreFinite() {
        for radius in stride(from: 0.0, through: 1.0, by: 0.005) {
            let gain = RadialGainCurve.gain(forRadius: radius)
            #expect(gain.isFinite)
            #expect(RadialGainCurve.decibels(forRadius: radius).isFinite)
            #expect(RadialGainCurve.radius(forGain: gain).isFinite)
        }
    }
}
