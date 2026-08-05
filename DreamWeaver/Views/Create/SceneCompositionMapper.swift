import CoreGraphics
import Foundation

/// Maps Create editor state ↔ `scene_composition_v1` for local reopen / remote draft sync.
enum SceneCompositionMapper {
    static func composition(
        from sources: [SpatialEditorSource],
        duration: Double
    ) -> APIContentDTO.SceneComposition {
        let tracks = sources.map { source -> APIContentDTO.CompositionTrack in
            let start = max(0, source.audioStartTime)
            let end = max(start + 1, min(source.audioEndTime, duration))
            let keyframes = normalizedKeyframes(for: source, start: start, end: end)
            return APIContentDTO.CompositionTrack(
                id: source.id,
                asset_id: nil,
                resource_key: resourceKey(for: source),
                layer: layer(for: source),
                loop: !source.isVoice,
                start_seconds: start,
                end_seconds: end,
                source_duration_seconds: source.audioDuration,
                keyframes: keyframes
            )
        }
        let durationSeconds = tracks.map(\.end_seconds).max() ?? duration
        return APIContentDTO.SceneComposition(
            schema: "scene_composition_v1",
            version: 1,
            duration_seconds: durationSeconds,
            tracks: tracks
        )
    }

    static func editorSources(
        from composition: APIContentDTO.SceneComposition
    ) -> [SpatialEditorSource] {
        composition.tracks.map { track in
            let material = material(forResourceKey: track.resource_key)
            let defaultPoint: CGPoint = {
                if let first = track.keyframes.first {
                    return point(angle: first.angle, radius: first.radius)
                }
                return material?.defaultPosition ?? .zero
            }()
            let keyPoints = track.keyframes.map { frame in
                SpatialKeyPoint(
                    time: frame.t,
                    position: point(angle: frame.angle, radius: frame.radius),
                    createdByUser: true
                )
            }
            let start = track.start_seconds
            let end = max(track.end_seconds, start + 1)
            return SpatialEditorSource(
                id: track.id,
                materialID: material?.id,
                name: material?.name ?? (track.resource_key ?? "声源"),
                iconName: material?.iconName ?? "waveform",
                theme: material?.theme ?? theme(forLayer: track.layer),
                defaultPosition: defaultPoint,
                keyPoints: keyPoints.isEmpty
                    ? [SpatialKeyPoint(time: start, position: defaultPoint, createdByUser: true)]
                    : keyPoints,
                audioStartTime: start,
                audioDuration: end - start,
                isVoice: material?.isVoice == true || track.layer == "voice"
            )
        }
    }

    static func resourceKey(for source: SpatialEditorSource) -> String {
        switch source.materialID {
        case "rain": return "rain_soft"
        case "wind": return "wind_realistic"
        case "bamboo": return "rain_bamboo_leaf"
        case "voice": return "voice_phrase_mom"
        // Bundle currently ships rain/wind/bamboo/stream/towel/voice/hair*; map others to closest loops.
        case "piano": return "stream_nature"
        case "insect": return "rain_bamboo_leaf"
        case "tide", "stream": return "stream_nature"
        case "fire": return "ac_hum"
        case "towel": return "hair_towel"
        case let id?: return "create_\(id)"
        case nil: return "create_custom"
        }
    }

    /// Flat `SoundSource` list for Create editor preview (LocalPlaybackService).
    static func playbackSources(
        from sources: [SpatialEditorSource],
        at time: Double
    ) -> [SoundSource] {
        sources.compactMap { source in
            let key = resourceKey(for: source)
            guard !key.hasPrefix("create_") else { return nil }
            let point = SpatialTrajectory.position(
                at: time,
                keyPoints: source.keyPoints,
                defaultPosition: source.defaultPosition
            )
            let radius = min(max(hypot(point.x, point.y), 0), 1)
            let angle = atan2(-point.y, point.x)
            let inWindow = time >= source.audioStartTime && time < source.audioEndTime
            return SoundSource(
                id: source.id,
                name: source.name,
                symbolName: source.iconName,
                isEnabled: inWindow,
                volume: inWindow ? 0.55 : 0,
                position: SpatialPosition(angle: angle, radius: radius),
                resourceName: key,
                // Preview uses continuous players; official `.voice` oneshots need a timeline.
                layer: .ambience
            )
        }
    }

    private static func layer(for source: SpatialEditorSource) -> String {
        if source.isVoice { return "voice" }
        switch source.theme {
        case .narration:
            return "voice"
        case .texture:
            return "trigger"
        case .water, .rain, .wind, .music, .fire, .nature:
            return "ambience"
        }
    }

    private static func theme(forLayer layer: String?) -> SpatialSourceTheme {
        switch layer {
        case "voice": return .narration
        case "trigger": return .texture
        case "environment": return .rain
        default: return .wind
        }
    }

    private static func material(forResourceKey key: String?) -> SpatialEditorMaterial? {
        guard let key else { return nil }
        let catalog = SpatialEditorMaterial.catalog
        switch key {
        case "rain_soft", "rain_parasol":
            return catalog.first { $0.id == "rain" }
        case "wind_realistic":
            return catalog.first { $0.id == "wind" }
        case "rain_bamboo_leaf":
            return catalog.first { $0.id == "bamboo" }
        case "voice_phrase_mom":
            return catalog.first { $0.id == "voice" }
        case "stream_nature":
            return catalog.first { $0.id == "stream" }
        case "hair_towel":
            return catalog.first { $0.id == "towel" }
        case "fireplace_soft":
            return catalog.first { $0.id == "fire" }
        case "piano_soft":
            return catalog.first { $0.id == "piano" }
        case "insect_night":
            return catalog.first { $0.id == "insect" }
        default:
            if key.hasPrefix("create_") {
                let materialID = String(key.dropFirst("create_".count))
                return catalog.first { $0.id == materialID }
            }
            return nil
        }
    }

    private static func normalizedKeyframes(
        for source: SpatialEditorSource,
        start: Double,
        end: Double
    ) -> [APIContentDTO.CompositionKeyframe] {
        let points = source.keyPoints.sorted { $0.time < $1.time }
        var frames: [APIContentDTO.CompositionKeyframe] = []
        var lastT: Double?

        let ensured: [SpatialKeyPoint]
        if points.isEmpty {
            ensured = [
                SpatialKeyPoint(time: start, position: source.defaultPosition, createdByUser: true)
            ]
        } else {
            ensured = points
        }

        for point in ensured {
            var t = min(max(point.time, start), end)
            if let lastT, t <= lastT {
                t = min(lastT + 0.05, end)
                if t <= lastT { continue }
            }
            let polar = polar(from: point.position)
            frames.append(
                APIContentDTO.CompositionKeyframe(
                    t: t,
                    angle: polar.angle,
                    radius: polar.radius,
                    volume: 0.5
                )
            )
            lastT = t
        }

        if frames.isEmpty {
            let polar = polar(from: source.defaultPosition)
            frames = [
                APIContentDTO.CompositionKeyframe(
                    t: start,
                    angle: polar.angle,
                    radius: polar.radius,
                    volume: 0.5
                )
            ]
        }
        return frames
    }

    /// Canvas coords match Create seed: x = cos(angle)*r, y = -sin(angle)*r.
    private static func polar(from point: CGPoint) -> (angle: Double, radius: Double) {
        let radius = min(max(hypot(point.x, point.y), 0), 1)
        let angle = atan2(-point.y, point.x)
        return (angle, radius)
    }

    private static func point(angle: Double, radius: Double) -> CGPoint {
        let r = min(max(radius, 0), 1)
        return CGPoint(x: cos(angle) * r, y: -sin(angle) * r)
    }
}
