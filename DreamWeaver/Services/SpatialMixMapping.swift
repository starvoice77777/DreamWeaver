import AVFoundation
import Foundation

/// Maps mix-board polar coordinates onto Apple's `AVAudioEnvironmentNode` world space.
///
/// Board model (ear-height plane):
/// - Angle 0 = right, π/2 = front (screen up), π = left, −π/2 = behind.
/// - Radius is perceived distance; attenuation is handled by the environment node.
///
/// Apple listener convention: +X right, +Y up, −Z forward.
enum SpatialMixMapping {
    /// Board radius clamp (must match `SpatialPosition.from`).
    static let minRadius = 0.22
    static let maxRadius = 0.95

    /// User mix gain when dropping a new source (distance is not encoded in volume).
    static let defaultMixGain = 0.72

    /// Meters for the near / far edge of the mix board.
    static let nearDistanceMeters: Float = 0.65
    static let farDistanceMeters: Float = 4.2

    /// Soft send into the environment's factory reverb.
    static let sourceReverbBlend: Float = 0.14

    static func worldPoint(from position: SpatialPosition) -> AVAudio3DPoint {
        let t = Float(radiusNormalized(position.radius))
        let meters = nearDistanceMeters + (farDistanceMeters - nearDistanceMeters) * t
        let angle = Float(position.angle)
        return AVAudio3DPoint(
            x: cos(angle) * meters,
            y: 0,
            z: -sin(angle) * meters
        )
    }

    static func configureEnvironment(_ environment: AVAudioEnvironmentNode) {
        environment.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
        environment.listenerAngularOrientation = AVAudioMake3DAngularOrientation(0, 0, 0)

        let attenuation = environment.distanceAttenuationParameters
        attenuation.distanceAttenuationModel = .inverseDistance
        attenuation.referenceDistance = nearDistanceMeters
        attenuation.maximumDistance = farDistanceMeters + 1.8
        attenuation.rolloffFactor = 1.2

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
        let available = environment.applicableRenderingAlgorithms
        if available.contains(.hrtFHQ) { return .hrtFHQ }
        if available.contains(.hrtF) { return .hrtF }
        if available.contains(.sphericalHead) { return .sphericalHead }
        return .equalPowerPanning
    }

    private static func radiusNormalized(_ radius: Double) -> Double {
        let span = maxRadius - minRadius
        guard span > 0 else { return 0 }
        return min(max((radius - minRadius) / span, 0), 1)
    }
}
