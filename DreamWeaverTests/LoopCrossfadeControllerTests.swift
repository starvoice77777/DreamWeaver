import Foundation
import Testing
@testable import DreamWeaver

@Suite("Loop crossfade controller")
struct LoopCrossfadeControllerTests {
    @Test("Crossfade starts with only the outgoing source")
    func progressZero() {
        let gains = LoopCrossfadeController.gains(at: 0)
        #expect(approximatelyEqual(gains.outgoing, 1))
        #expect(approximatelyEqual(gains.incoming, 0))
    }

    @Test("Crossfade ends with only the incoming source")
    func progressOne() {
        let gains = LoopCrossfadeController.gains(at: 1)
        #expect(approximatelyEqual(gains.outgoing, 0))
        #expect(approximatelyEqual(gains.incoming, 1))
    }

    @Test("Crossfade midpoint has equal square-root gains")
    func progressMidpoint() {
        let gains = LoopCrossfadeController.gains(at: 0.5)
        let expected = Float(sqrt(0.5))
        #expect(approximatelyEqual(gains.outgoing, expected))
        #expect(approximatelyEqual(gains.incoming, expected))
    }

    @Test(
        "Crossfade preserves equal power",
        arguments: [0.0, 0.1, 0.25, 0.5, 0.75, 0.9, 1.0]
    )
    func equalPower(progress: Double) {
        let gains = LoopCrossfadeController.gains(at: progress)
        let power = gains.outgoing * gains.outgoing + gains.incoming * gains.incoming
        #expect(approximatelyEqual(power, 1, tolerance: 1e-5))
    }

    @Test("Crossfade progress is clamped")
    func progressIsClamped() {
        #expect(LoopCrossfadeController.gains(at: -1) == LoopCrossfadeController.gains(at: 0))
        #expect(LoopCrossfadeController.gains(at: 2) == LoopCrossfadeController.gains(at: 1))
    }

    @Test("Non-positive milliseconds disable crossfade")
    func invalidMilliseconds() {
        #expect(LoopCrossfadeController.validatedDuration(
            milliseconds: 0,
            sourceDurationSeconds: 10
        ) == 0)
        #expect(LoopCrossfadeController.validatedDuration(
            milliseconds: -20,
            sourceDurationSeconds: 10
        ) == 0)
    }

    @Test("Non-positive source duration disables crossfade")
    func invalidSourceDuration() {
        #expect(LoopCrossfadeController.validatedDuration(
            milliseconds: 500,
            sourceDurationSeconds: 0
        ) == 0)
    }

    @Test("Milliseconds convert to seconds")
    func millisecondsConvertToSeconds() {
        #expect(approximatelyEqual(
            LoopCrossfadeController.validatedDuration(
                milliseconds: 750,
                sourceDurationSeconds: 10
            ),
            0.75
        ))
    }

    @Test("Crossfade is capped at forty-nine percent of the source")
    func durationCap() {
        #expect(approximatelyEqual(
            LoopCrossfadeController.validatedDuration(
                milliseconds: 5_000,
                sourceDurationSeconds: 2
            ),
            0.98
        ))
    }

    @Test(
        "Known resources restore their preferred crossfade",
        arguments: [
            ("rain_soft", 1_000),
            ("rain_parasol", 1_200),
            ("rain_bamboo_leaf", 800),
            ("hair_wash_foam_rub", 1_200)
        ]
    )
    func preferredResourceDuration(resourceKey: String, milliseconds: Int) {
        #expect(LoopCrossfadeController.preferredMilliseconds(for: resourceKey) == milliseconds)
    }

    @Test("Unknown and absent resource keys have no preset")
    func unknownResourceDuration() {
        #expect(LoopCrossfadeController.preferredMilliseconds(for: "unknown") == 0)
        #expect(LoopCrossfadeController.preferredMilliseconds(for: nil) == 0)
    }
}
