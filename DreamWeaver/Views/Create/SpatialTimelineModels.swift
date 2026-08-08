import SwiftUI

/// A user-authored「定位点」in「空间轨迹」.
struct SpatialKeyPoint: Identifiable, Equatable, Codable {
    let id: UUID
    var time: Double
    var position: CGPoint
    var createdByUser: Bool
    /// Segment interpolation from this point to the next. Optional keeps older
    /// local drafts decodable; manual sparse points default to smoothstep.
    var interpolation: SceneInterpolationMode?

    init(
        id: UUID = UUID(),
        time: Double,
        position: CGPoint,
        createdByUser: Bool = true,
        interpolation: SceneInterpolationMode? = nil
    ) {
        self.id = id
        self.time = time
        self.position = position
        self.createdByUser = createdByUser
        self.interpolation = interpolation
    }
}

/// One time-position sample captured while the user is dragging a source.
struct SpatialMotionSample: Identifiable, Equatable, Codable {
    let id: UUID
    var time: Double
    var position: CGPoint

    init(id: UUID = UUID(), time: Double, position: CGPoint) {
        self.id = id
        self.time = time
        self.position = SpatialTrajectory.clampedToUnitCircle(position)
    }
}

/// A continuous, linearly-interpolated drag recording. Keeping recordings as
/// clips makes punch-in replacement and one-step undo possible without exposing
/// hundreds of samples as individually editable timeline points.
struct SpatialMotionClip: Identifiable, Equatable, Codable {
    let id: UUID
    var samples: [SpatialMotionSample]

    init(id: UUID = UUID(), samples: [SpatialMotionSample]) {
        self.id = id
        self.samples = samples.sorted { $0.time < $1.time }
    }

    var startTime: Double { samples.first?.time ?? 0 }
    var endTime: Double { samples.last?.time ?? startTime }
    var duration: Double { max(endTime - startTime, 0) }
}

/// A short user-authored line scheduled on the scene timeline.
struct SpatialTextCue: Identifiable, Equatable, Codable {
    let id: UUID
    var time: Double
    var text: String

    init(id: UUID = UUID(), time: Double, text: String) {
        self.id = id
        self.time = time
        self.text = text
    }
}

enum SpatialSourceTheme: String, Equatable, Codable {
    case narration
    case texture
    case water
    case rain
    case wind
    case music
    case fire
    case nature

    var color: Color {
        switch self {
        case .narration:
            return Color(hex: 0x9FCB7A)
        case .texture:
            return Color(hex: 0xE1A15D)
        case .water:
            return Color(hex: 0x6CAFE8)
        case .rain:
            return Color(hex: 0x7BA4D8)
        case .wind:
            return Color(hex: 0xA8B7C8)
        case .music:
            return Color(hex: 0xC9A0DC)
        case .fire:
            return Color(hex: 0xE08A5A)
        case .nature:
            return Color(hex: 0x86B88A)
        }
    }
}

/// Catalog entry for materials that can be added into the spatial editor.
struct SpatialEditorMaterial: Identifiable, Equatable {
    let id: String
    let name: String
    let iconName: String
    let theme: SpatialSourceTheme
    let defaultPosition: CGPoint
    var assetID: UUID? = nil
    var resourceName: String? = nil
    var audioDuration: Double? = nil
    /// Voice clips remain independent audio blocks while sharing one source track.
    var isVoice: Bool = false

    var themeColor: Color { theme.color }

    static let catalog: [SpatialEditorMaterial] = [
        .init(
            id: "rain",
            name: "雨声",
            iconName: "cloud.rain.fill",
            theme: .rain,
            defaultPosition: CGPoint(x: 0, y: -0.78)
        ),
        .init(
            id: "wind",
            name: "风声",
            iconName: "wind",
            theme: .wind,
            defaultPosition: CGPoint(x: -0.58, y: -0.18)
        ),
        .init(
            id: "bamboo",
            name: "竹叶雨",
            iconName: "leaf.fill",
            theme: .nature,
            defaultPosition: CGPoint(x: 0.48, y: -0.42)
        ),
        .init(
            id: "voice",
            name: "人声·旁白",
            iconName: "person.wave.2.fill",
            theme: .narration,
            defaultPosition: CGPoint(x: 0, y: -0.55),
            isVoice: true
        ),
        .init(
            id: "piano",
            name: "钢琴",
            iconName: "pianokeys",
            theme: .music,
            defaultPosition: CGPoint(x: -0.36, y: 0.36)
        ),
        .init(
            id: "insect",
            name: "虫鸣",
            iconName: "ant.fill",
            theme: .nature,
            defaultPosition: CGPoint(x: 0.52, y: 0.28)
        ),
        .init(
            id: "tide",
            name: "潮声",
            iconName: "water.waves",
            theme: .water,
            defaultPosition: CGPoint(x: -0.62, y: 0.22)
        ),
        .init(
            id: "stream",
            name: "流水·近景",
            iconName: "drop.fill",
            theme: .water,
            defaultPosition: CGPoint(x: 0, y: 0.55)
        ),
        .init(
            id: "fire",
            name: "炉火",
            iconName: "flame.fill",
            theme: .fire,
            defaultPosition: CGPoint(x: 0.28, y: 0.48)
        ),
        .init(
            id: "towel",
            name: "毛巾摩擦",
            iconName: "hand.raised.fingers.spread.fill",
            theme: .texture,
            defaultPosition: CGPoint(x: 0.40, y: 0.02)
        )
    ]

    static func from(_ asset: SoundAsset) -> SpatialEditorMaterial {
        let isVoice = asset.kind == .seed
        let theme: SpatialSourceTheme = isVoice
            ? .narration
            : (asset.kind == .community ? .nature : .texture)
        let position: CGPoint = {
            switch asset.kind {
            case .seed: return CGPoint(x: 0, y: -0.52)
            case .recording: return CGPoint(x: 0.38, y: 0.12)
            case .community: return CGPoint(x: -0.38, y: 0.12)
            }
        }()
        return SpatialEditorMaterial(
            id: "library-\(asset.id.uuidString)",
            name: asset.name,
            iconName: asset.symbolName,
            theme: theme,
            defaultPosition: position,
            assetID: asset.id,
            resourceName: asset.previewResourceName,
            audioDuration: Double(asset.durationSeconds),
            isVoice: isVoice
        )
    }
}

enum SpatialTimelineEditMode: String, CaseIterable, Identifiable {
    case audioTiming
    case spatialTrajectory

    var id: String { rawValue }

    var title: String {
        switch self {
        case .audioTiming:
            return "时间编排"
        case .spatialTrajectory:
            return "空间轨迹"
        }
    }

    var iconName: String {
        switch self {
        case .audioTiming:
            return "waveform"
        case .spatialTrajectory:
            return "point.topleft.down.to.point.bottomright.curvepath"
        }
    }
}

/// Editor-local source model. It deliberately stays under Views/Create so the
/// composition demo does not mutate the existing playback `SoundSource` model.
struct SpatialEditorSource: Identifiable, Equatable, Codable {
    let id: UUID
    /// Stable disk identity. Several clips (for example narration phrases) may
    /// share one source group while remaining separate timeline rows.
    var sourceGroupID: UUID?
    var materialID: String?
    var assetID: UUID?
    var resourceName: String?
    var name: String
    var iconName: String
    var theme: SpatialSourceTheme
    var defaultPosition: CGPoint
    var keyPoints: [SpatialKeyPoint]
    /// Optional keeps local drafts created before trajectory recording decodable.
    var motionClips: [SpatialMotionClip]?
    /// Playback range is independent from spatial positioning points.
    var audioStartTime: Double
    var audioDuration: Double
    /// Preserves whether the imported clip is a continuous bed or a one-shot.
    /// Optional keeps drafts created before official-timeline import decodable.
    var isLooping: Bool?
    var sourceOffsetSeconds: Double?
    var crossfadeMilliseconds: Int?
    var fadeInMilliseconds: Int?
    var fadeOutMilliseconds: Int?
    var isVoice: Bool

    var themeColor: Color { theme.color }
    var audioEndTime: Double { audioStartTime + audioDuration }
    var effectiveSourceGroupID: UUID { sourceGroupID ?? id }

    init(
        id: UUID = UUID(),
        sourceGroupID: UUID? = nil,
        materialID: String? = nil,
        assetID: UUID? = nil,
        resourceName: String? = nil,
        name: String,
        iconName: String,
        theme: SpatialSourceTheme,
        defaultPosition: CGPoint,
        keyPoints: [SpatialKeyPoint],
        motionClips: [SpatialMotionClip] = [],
        audioStartTime: Double = 0,
        audioDuration: Double = 120,
        isLooping: Bool? = nil,
        sourceOffsetSeconds: Double = 0,
        crossfadeMilliseconds: Int? = nil,
        fadeInMilliseconds: Int = 0,
        fadeOutMilliseconds: Int = 0,
        isVoice: Bool = false
    ) {
        self.id = id
        self.sourceGroupID = sourceGroupID
        self.materialID = materialID
        self.assetID = assetID
        self.resourceName = resourceName
        self.name = name
        self.iconName = iconName
        self.theme = theme
        self.defaultPosition = SpatialTrajectory.clampedToUnitCircle(defaultPosition)
        self.keyPoints = keyPoints.sorted { $0.time < $1.time }
        self.motionClips = motionClips.isEmpty ? nil : motionClips.sorted { $0.startTime < $1.startTime }
        self.audioStartTime = max(0, audioStartTime)
        self.audioDuration = max(1, audioDuration)
        self.isLooping = isLooping
        self.sourceOffsetSeconds = max(sourceOffsetSeconds, 0)
        self.crossfadeMilliseconds = crossfadeMilliseconds.map { max($0, 0) }
        self.fadeInMilliseconds = max(fadeInMilliseconds, 0)
        self.fadeOutMilliseconds = max(fadeOutMilliseconds, 0)
        self.isVoice = isVoice
    }
}

/// One independently editable audio range owned by a logical spatial source.
/// The editor keeps clips separate from the disk source so repeated appearances
/// share one track and one trajectory without duplicating authoring state.
struct SpatialEditorAudioClip: Identifiable, Equatable, Codable {
    let id: UUID
    var sourceGroupID: UUID
    var assetID: UUID?
    var resourceName: String?
    var startTime: Double
    var duration: Double
    var isLooping: Bool
    var sourceOffsetSeconds: Double
    var crossfadeMilliseconds: Int?
    var fadeInMilliseconds: Int
    var fadeOutMilliseconds: Int
    var isVoicePhrase: Bool

    var endTime: Double { startTime + duration }

    init(
        id: UUID = UUID(),
        sourceGroupID: UUID,
        assetID: UUID? = nil,
        resourceName: String? = nil,
        startTime: Double,
        duration: Double,
        isLooping: Bool,
        sourceOffsetSeconds: Double = 0,
        crossfadeMilliseconds: Int? = nil,
        fadeInMilliseconds: Int = 0,
        fadeOutMilliseconds: Int = 0,
        isVoicePhrase: Bool = false
    ) {
        self.id = id
        self.sourceGroupID = sourceGroupID
        self.assetID = assetID
        self.resourceName = resourceName
        self.startTime = max(startTime, 0)
        self.duration = max(duration, 1)
        self.isLooping = isLooping
        self.sourceOffsetSeconds = max(sourceOffsetSeconds, 0)
        self.crossfadeMilliseconds = crossfadeMilliseconds.map { max($0, 0) }
        self.fadeInMilliseconds = max(fadeInMilliseconds, 0)
        self.fadeOutMilliseconds = max(fadeOutMilliseconds, 0)
        self.isVoicePhrase = isVoicePhrase
    }
}

/// Transitional name for the group-level editor model. `SpatialEditorSource`
/// remains Codable so existing local drafts can be migrated without data loss.
typealias SpatialEditorSourceGroup = SpatialEditorSource

struct SpatialEditorDocument: Equatable {
    var sourceGroups: [SpatialEditorSourceGroup]
    var audioClips: [SpatialEditorAudioClip]

    static func migrate(
        legacySources: [SpatialEditorSource]
    ) -> SpatialEditorDocument {
        var inferredGroupIDs: [String: UUID] = [:]
        var groupIDBySourceID: [UUID: UUID] = [:]
        for source in legacySources {
            if let explicit = source.sourceGroupID {
                groupIDBySourceID[source.id] = explicit
                continue
            }
            let identity = source.materialID.map { "material:\($0)" }
                ?? source.assetID.map { "asset:\($0.uuidString)" }
                ?? source.resourceName.map { "resource:\($0)" }
                ?? "display:\(source.name):\(source.iconName)"
            let groupID = inferredGroupIDs[identity] ?? source.id
            inferredGroupIDs[identity] = groupID
            groupIDBySourceID[source.id] = groupID
        }
        let grouped = Dictionary(grouping: legacySources) {
            groupIDBySourceID[$0.id] ?? $0.effectiveSourceGroupID
        }
        let orderedGroupIDs = legacySources.reduce(into: [UUID]()) { result, source in
            let id = groupIDBySourceID[source.id] ?? source.effectiveSourceGroupID
            if !result.contains(id) { result.append(id) }
        }
        let groups = orderedGroupIDs.compactMap { groupID -> SpatialEditorSourceGroup? in
            guard let members = grouped[groupID], let representative = members.first else {
                return nil
            }
            var points: [SpatialKeyPoint] = []
            for point in members.flatMap(\.keyPoints).sorted(by: { $0.time < $1.time }) {
                if let index = points.firstIndex(where: { abs($0.time - point.time) < 0.001 }) {
                    points[index] = point
                } else {
                    points.append(point)
                }
            }
            var motionClips: [SpatialMotionClip] = []
            for clip in members.flatMap({ $0.motionClips ?? [] }) {
                if !motionClips.contains(where: { $0.id == clip.id }) {
                    motionClips.append(clip)
                }
            }
            return SpatialEditorSource(
                id: groupID,
                sourceGroupID: groupID,
                materialID: representative.materialID,
                assetID: representative.assetID,
                resourceName: representative.resourceName,
                name: representative.name,
                iconName: representative.iconName,
                theme: representative.theme,
                defaultPosition: representative.defaultPosition,
                keyPoints: points,
                motionClips: motionClips,
                audioStartTime: 0,
                audioDuration: 1,
                isLooping: representative.isLooping,
                isVoice: members.contains(where: \.isVoice)
            )
        }
        let clips = legacySources.map { source in
            SpatialEditorAudioClip(
                id: source.id,
                sourceGroupID: groupIDBySourceID[source.id] ?? source.effectiveSourceGroupID,
                assetID: source.assetID,
                resourceName: source.resourceName,
                startTime: source.audioStartTime,
                duration: source.audioDuration,
                isLooping: source.isLooping ?? !source.isVoice,
                sourceOffsetSeconds: source.sourceOffsetSeconds ?? 0,
                crossfadeMilliseconds: source.crossfadeMilliseconds,
                fadeInMilliseconds: source.fadeInMilliseconds ?? 0,
                fadeOutMilliseconds: source.fadeOutMilliseconds ?? 0,
                isVoicePhrase: source.isVoice
            )
        }
        return SpatialEditorDocument(sourceGroups: groups, audioClips: clips)
    }

    func legacySources() -> [SpatialEditorSource] {
        let groupsByID = Dictionary(uniqueKeysWithValues: sourceGroups.map { ($0.id, $0) })
        return audioClips.compactMap { clip in
            guard let group = groupsByID[clip.sourceGroupID] else { return nil }
            return SpatialEditorSource(
                id: clip.id,
                sourceGroupID: group.id,
                materialID: group.materialID,
                assetID: clip.assetID,
                resourceName: clip.resourceName,
                name: group.name,
                iconName: group.iconName,
                theme: group.theme,
                defaultPosition: group.defaultPosition,
                keyPoints: group.keyPoints,
                motionClips: group.motionClips ?? [],
                audioStartTime: clip.startTime,
                audioDuration: clip.duration,
                isLooping: clip.isLooping,
                sourceOffsetSeconds: clip.sourceOffsetSeconds,
                crossfadeMilliseconds: clip.crossfadeMilliseconds,
                fadeInMilliseconds: clip.fadeInMilliseconds,
                fadeOutMilliseconds: clip.fadeOutMilliseconds,
                isVoice: group.isVoice || clip.isVoicePhrase
            )
        }
    }
}

struct SpatialGeneratedBoundaryKeyPoint: Identifiable, Equatable {
    enum Attachment: Equatable {
        case clipEnd(UUID)
        case clipStart(UUID)
    }

    let id: String
    let time: Double
    let position: CGPoint
    let attachment: Attachment
}

struct TimelineViewport: Equatable {
    static let defaultSpan: Double = 30
    static let minimumSpan: Double = 5

    var startTime: Double
    var span: Double

    var endTime: Double { startTime + span }

    init(sceneDuration: Double, startTime: Double = 0, span: Double = defaultSpan) {
        let safeDuration = max(sceneDuration, 1)
        self.span = min(max(span, min(Self.minimumSpan, safeDuration)), safeDuration)
        self.startTime = min(max(startTime, 0), max(safeDuration - self.span, 0))
    }

    mutating func clamp(to sceneDuration: Double) {
        let safeDuration = max(sceneDuration, 1)
        span = min(max(span, min(Self.minimumSpan, safeDuration)), safeDuration)
        startTime = min(max(startTime, 0), max(safeDuration - span, 0))
    }

    func x(for time: Double, width: CGFloat) -> CGFloat {
        CGFloat((time - startTime) / max(span, 0.000_1)) * width
    }

    func time(for x: CGFloat, width: CGFloat) -> Double {
        startTime + Double(min(max(x / max(width, 1), 0), 1)) * span
    }
}

enum SpatialTrajectory {
    static func position(at time: Double, source: SpatialEditorSource) -> CGPoint {
        let clips = (source.motionClips ?? []).sorted { $0.startTime < $1.startTime }
        if let clip = clips.last(where: { time >= $0.startTime && time <= $0.endTime }) {
            return position(at: time, samples: clip.samples, defaultPosition: source.defaultPosition)
        }

        var anchors = source.keyPoints
        for clip in clips {
            if let first = clip.samples.first {
                anchors.append(
                    SpatialKeyPoint(
                        time: first.time,
                        position: first.position,
                        createdByUser: false
                    )
                )
            }
            if let last = clip.samples.last, last.time > clip.startTime {
                anchors.append(
                    SpatialKeyPoint(
                        time: last.time,
                        position: last.position,
                        createdByUser: false
                    )
                )
            }
        }

        return position(
            at: time,
            keyPoints: deduplicatedKeyPoints(anchors),
            defaultPosition: source.defaultPosition
        )
    }

    /// Smoothly evaluates sparse user positioning points without persisting any
    /// generated samples. Coordinates are normalized to the unit sound field.
    static func position(
        at time: Double,
        keyPoints: [SpatialKeyPoint],
        defaultPosition: CGPoint
    ) -> CGPoint {
        let points = keyPoints.sorted { $0.time < $1.time }
        guard let first = points.first else {
            return clampedToUnitCircle(defaultPosition)
        }
        guard points.count > 1 else {
            return clampedToUnitCircle(first.position)
        }
        if time <= first.time {
            return clampedToUnitCircle(first.position)
        }
        guard let last = points.last else {
            return clampedToUnitCircle(first.position)
        }
        if time >= last.time {
            return clampedToUnitCircle(last.position)
        }

        guard let upperIndex = points.firstIndex(where: { $0.time >= time }),
              upperIndex > 0 else {
            return clampedToUnitCircle(first.position)
        }

        let start = points[upperIndex - 1]
        let end = points[upperIndex]
        let interval = max(end.time - start.time, 0.000_1)
        let progress = min(max((time - start.time) / interval, 0), 1)
        let evaluatedProgress: Double
        switch start.interpolation ?? .smoothstep {
        case .linear, .recordedLinear:
            evaluatedProgress = progress
        case .smoothstep:
            evaluatedProgress = progress * progress * (3 - 2 * progress)
        case .hold:
            evaluatedProgress = progress < 1 ? 0 : 1
        }

        return clampedToUnitCircle(
            CGPoint(
                x: start.position.x
                    + (end.position.x - start.position.x) * evaluatedProgress,
                y: start.position.y
                    + (end.position.y - start.position.y) * evaluatedProgress
            )
        )
    }

    /// Linear evaluation preserves the timing and velocity authored by a live drag.
    static func position(
        at time: Double,
        samples: [SpatialMotionSample],
        defaultPosition: CGPoint
    ) -> CGPoint {
        let points = samples.sorted { $0.time < $1.time }
        guard let first = points.first else {
            return clampedToUnitCircle(defaultPosition)
        }
        guard points.count > 1, let last = points.last else {
            return clampedToUnitCircle(first.position)
        }
        if time <= first.time { return clampedToUnitCircle(first.position) }
        if time >= last.time { return clampedToUnitCircle(last.position) }

        guard let upperIndex = points.firstIndex(where: { $0.time >= time }),
              upperIndex > 0 else {
            return clampedToUnitCircle(first.position)
        }
        let start = points[upperIndex - 1]
        let end = points[upperIndex]
        let interval = max(end.time - start.time, 0.000_1)
        let progress = min(max((time - start.time) / interval, 0), 1)
        return clampedToUnitCircle(
            CGPoint(
                x: start.position.x + (end.position.x - start.position.x) * progress,
                y: start.position.y + (end.position.y - start.position.y) * progress
            )
        )
    }

    /// Expands recording clips only at the persistence boundary. Manual points
    /// covered by a recording are intentionally omitted because the recording
    /// has precedence inside its punch-in range.
    static func flattenedKeyPoints(for source: SpatialEditorSource) -> [SpatialKeyPoint] {
        let clips = source.motionClips ?? []
        var points = source.keyPoints.filter { point in
            !clips.contains { point.time >= $0.startTime && point.time <= $0.endTime }
        }
        for clip in clips {
            points.append(contentsOf: clip.samples.map {
                SpatialKeyPoint(
                    time: $0.time,
                    position: $0.position,
                    createdByUser: false,
                    interpolation: .recordedLinear
                )
            })
        }
        return deduplicatedKeyPoints(points)
    }

    /// Produces a compact, time-aware representation of raw 20 Hz drag samples.
    /// The simplifier compares each point with its time-correct linear prediction,
    /// so pauses and changes in speed remain visible after geometric compression.
    static func processedRecordingSamples(
        _ rawSamples: [SpatialMotionSample],
        tolerance: CGFloat = 0.009,
        maximumCount: Int = 600
    ) -> [SpatialMotionSample] {
        let ordered = deduplicatedSamples(rawSamples)
        guard ordered.count > 2 else { return ordered }

        let smoothed = ordered.enumerated().map { index, sample in
            guard index > 0, index < ordered.count - 1 else { return sample }
            let previous = ordered[index - 1].position
            let next = ordered[index + 1].position
            let position = CGPoint(
                x: previous.x * 0.18 + sample.position.x * 0.64 + next.x * 0.18,
                y: previous.y * 0.18 + sample.position.y * 0.64 + next.y * 0.18
            )
            return SpatialMotionSample(id: sample.id, time: sample.time, position: position)
        }

        var currentTolerance = tolerance
        var simplified = simplify(smoothed, tolerance: currentTolerance)
        while simplified.count > maximumCount {
            currentTolerance *= 1.35
            simplified = simplify(smoothed, tolerance: currentTolerance)
        }
        return simplified
    }

    static func sliced(
        _ clip: SpatialMotionClip,
        from lowerBound: Double,
        through upperBound: Double
    ) -> SpatialMotionClip? {
        let lower = max(lowerBound, clip.startTime)
        let upper = min(upperBound, clip.endTime)
        guard upper - lower >= 0.05 else { return nil }

        var samples = clip.samples.filter { $0.time > lower && $0.time < upper }
        samples.insert(
            SpatialMotionSample(
                time: lower,
                position: position(at: lower, samples: clip.samples, defaultPosition: .zero)
            ),
            at: 0
        )
        samples.append(
            SpatialMotionSample(
                time: upper,
                position: position(at: upper, samples: clip.samples, defaultPosition: .zero)
            )
        )
        return SpatialMotionClip(samples: deduplicatedSamples(samples))
    }

    static func neighboringPoints(
        at time: Double,
        keyPoints: [SpatialKeyPoint]
    ) -> (previous: SpatialKeyPoint?, next: SpatialKeyPoint?) {
        let points = keyPoints.sorted { $0.time < $1.time }
        let previous = points.last(where: { $0.time <= time })
        let next = points.first(where: { $0.time >= time && $0.id != previous?.id })
        return (previous, next)
    }

    static func clampedToUnitCircle(_ point: CGPoint) -> CGPoint {
        let distance = hypot(point.x, point.y)
        guard distance > 1 else { return point }
        guard distance > 0 else { return .zero }
        return CGPoint(x: point.x / distance, y: point.y / distance)
    }

    private static func deduplicatedKeyPoints(_ points: [SpatialKeyPoint]) -> [SpatialKeyPoint] {
        var result: [SpatialKeyPoint] = []
        for point in points.sorted(by: { $0.time < $1.time }) {
            if let last = result.last, abs(last.time - point.time) < 0.001 {
                result[result.count - 1] = point
            } else {
                result.append(point)
            }
        }
        return result
    }

    private static func deduplicatedSamples(
        _ samples: [SpatialMotionSample]
    ) -> [SpatialMotionSample] {
        var result: [SpatialMotionSample] = []
        for sample in samples.sorted(by: { $0.time < $1.time }) {
            let clamped = SpatialMotionSample(
                id: sample.id,
                time: sample.time,
                position: sample.position
            )
            if let last = result.last, abs(last.time - clamped.time) < 0.01 {
                result[result.count - 1] = clamped
            } else {
                result.append(clamped)
            }
        }
        return result
    }

    private static func simplify(
        _ samples: [SpatialMotionSample],
        tolerance: CGFloat
    ) -> [SpatialMotionSample] {
        guard samples.count > 2,
              let first = samples.first,
              let last = samples.last else {
            return samples
        }

        let interval = max(last.time - first.time, 0.000_1)
        var largestDistance: CGFloat = 0
        var largestIndex = 0
        for index in 1..<(samples.count - 1) {
            let sample = samples[index]
            let progress = min(max((sample.time - first.time) / interval, 0), 1)
            let predicted = CGPoint(
                x: first.position.x + (last.position.x - first.position.x) * progress,
                y: first.position.y + (last.position.y - first.position.y) * progress
            )
            let distance = hypot(
                sample.position.x - predicted.x,
                sample.position.y - predicted.y
            )
            if distance > largestDistance {
                largestDistance = distance
                largestIndex = index
            }
        }

        guard largestDistance > tolerance else { return [first, last] }
        let left = simplify(Array(samples[0...largestIndex]), tolerance: tolerance)
        let right = simplify(Array(samples[largestIndex...]), tolerance: tolerance)
        return Array(left.dropLast()) + right
    }
}

enum SpatialTimeText {
    static func string(_ seconds: Double) -> String {
        let clamped = max(seconds, 0)
        let wholeSeconds = Int(clamped.rounded())
        return String(format: "%d:%02d", wholeSeconds / 60, wholeSeconds % 60)
    }
}
