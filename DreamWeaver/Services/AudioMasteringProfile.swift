import Foundation

/// Calibrates delivered masters to a shared playback baseline before the
/// user-facing radius gain is applied. This is source normalization, not a
/// second volume control: equal radii should sound comparably loud even when
/// the original recordings were mastered at very different levels.
enum AudioMasteringProfile {
    private struct Payload: Decodable {
        let targetIntegratedLoudnessDB: Double
        let maximumOutputTruePeakDB: Double
        let minimumCompensationDB: Double
        let maximumCompensationDB: Double
        let aliases: [String: String]
        let measurements: [String: Measurement]

        static let empty = Payload(
            targetIntegratedLoudnessDB: -24,
            maximumOutputTruePeakDB: -1,
            minimumCompensationDB: -6,
            maximumCompensationDB: 24,
            aliases: [:],
            measurements: [:]
        )
    }

    private struct Measurement: Decodable {
        let integratedLoudnessDB: Double
        let truePeakDB: Double
    }

    private static let payload = loadPayload()

    static func compensationDB(for resourceName: String) -> Float {
        let requestedKey = (resourceName as NSString).deletingPathExtension
        let canonicalKey = payload.aliases[requestedKey] ?? requestedKey
        guard let measurement = payload.measurements[canonicalKey] else { return 0 }

        let loudnessCompensation =
            payload.targetIntegratedLoudnessDB - measurement.integratedLoudnessDB
        let peakSafeCompensation =
            payload.maximumOutputTruePeakDB - measurement.truePeakDB
        let compensation = min(
            loudnessCompensation,
            peakSafeCompensation,
            payload.maximumCompensationDB
        )
        return Float(max(compensation, payload.minimumCompensationDB))
    }

    private static func loadPayload() -> Payload {
        let candidateSubdirectories: [String?] = ["Audio", "Resources/Audio", nil]
        for subdirectory in candidateSubdirectories {
            guard let url = Bundle.main.url(
                forResource: "audio_mastering_profile",
                withExtension: "json",
                subdirectory: subdirectory
            ), let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(Payload.self, from: data) else {
                continue
            }
            return decoded
        }
        return .empty
    }
}
