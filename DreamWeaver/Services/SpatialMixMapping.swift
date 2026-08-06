import AVFoundation
import Foundation

/// Maps mix-board polar coordinates onto Apple's `AVAudioEnvironmentNode` world space.
///
/// Board model (ear-height plane):
/// - Angle 0 = front (screen up), π/2 = right, -π/2 = left.
/// - Radius is the sole user-facing loudness control.
///
/// Apple listener convention: +X right, +Y up, −Z forward.
enum SpatialMixMapping {
    /// Board radius clamp (must match `SpatialPosition.from`).
    static let minRadius = 0.0
    static let maxRadius = 1.0

    /// All sources stay at this physical distance so AVFoundation only supplies
    /// direction/HRTF. Loudness is calculated from board radius exactly once.
    static let directionalDistanceMeters: Float = 1.0

    /// Gain at the outer edge of the board. The curve is exponential so the
    /// center stays expressive while distant sources remain audible.
    static let farEdgeGain: Double = 0.18

    /// Soft send into the environment's factory reverb.
    static let sourceReverbBlend: Float = 0.14

    static func worldPoint(from position: SpatialPosition) -> AVAudio3DPoint {
        let angle = Float(position.angle)
        return AVAudio3DPoint(
            x: sin(angle) * directionalDistanceMeters,
            y: 0,
            z: -cos(angle) * directionalDistanceMeters
        )
    }

    /// Deterministic user gain for a point on the mix disk.
    /// Equal radii always return equal gains, regardless of bearing.
    static func gain(for radius: Double) -> Double {
        pow(farEdgeGain, radiusNormalized(radius))
    }

    static func configureEnvironment(_ environment: AVAudioEnvironmentNode) {
        environment.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
        environment.listenerAngularOrientation = AVAudioMake3DAngularOrientation(0, 0, 0)

        let attenuation = environment.distanceAttenuationParameters
        attenuation.distanceAttenuationModel = .exponential
        attenuation.referenceDistance = directionalDistanceMeters
        attenuation.maximumDistance = directionalDistanceMeters
        attenuation.rolloffFactor = 0

        environment.reverbParameters.enable = true
        environment.reverbParameters.loadFactoryReverbPreset(.smallRoom)
    }

    static func applySourceSpatialization(
        to node: AVAudioPlayerNode,
        position: SpatialPosition,
        environment: AVAudioEnvironmentNode
    ) {
        node.position = worldPoint(from: position)
        node.pan = 0
        node.reverbBlend = sourceReverbBlend
        node.renderingAlgorithm = preferredRenderingAlgorithm(in: environment)
        node.sourceMode = .spatializeIfMono
    }

    private static func preferredRenderingAlgorithm(
        in environment: AVAudioEnvironmentNode
    ) -> AVAudio3DMixingRenderingAlgorithm {
        // `applicableRenderingAlgorithms` is bridged as [NSNumber].
        let available = Set(environment.applicableRenderingAlgorithms.map(\.intValue))
        let preferred: [AVAudio3DMixingRenderingAlgorithm] = [
            .HRTFHQ,
            .HRTF,
            .sphericalHead,
            .equalPowerPanning
        ]
        return preferred.first { available.contains($0.rawValue) } ?? .equalPowerPanning
    }

    private static func radiusNormalized(_ radius: Double) -> Double {
        let span = maxRadius - minRadius
        guard span > 0 else { return 0 }
        return min(max((radius - minRadius) / span, 0), 1)
    }
}
