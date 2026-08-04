import SwiftUI

/// A user-authored「定位点」in「空间轨迹」.
struct SpatialKeyPoint: Identifiable, Equatable {
    let id: UUID
    var time: Double
    var position: CGPoint
    var createdByUser: Bool

    init(
        id: UUID = UUID(),
        time: Double,
        position: CGPoint,
        createdByUser: Bool = true
    ) {
        self.id = id
        self.time = time
        self.position = position
        self.createdByUser = createdByUser
    }
}

/// A short user-authored line scheduled on the scene timeline.
struct SpatialTextCue: Identifiable, Equatable {
    let id: UUID
    var time: Double
    var text: String

    init(id: UUID = UUID(), time: Double, text: String) {
        self.id = id
        self.time = time
        self.text = text
    }
}

enum SpatialSourceTheme: Equatable {
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
    /// Voice tracks are exclusive per scene; natural sounds may stack.
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
}

enum SpatialTimelineEditMode: String, CaseIterable, Identifiable {
    case audioTiming
    case spatialTrajectory

    var id: String { rawValue }

    var title: String {
        switch self {
        case .audioTiming:
            return "音频时间"
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
struct SpatialEditorSource: Identifiable, Equatable {
    let id: UUID
    var materialID: String?
    var name: String
    var iconName: String
    var theme: SpatialSourceTheme
    var defaultPosition: CGPoint
    var keyPoints: [SpatialKeyPoint]
    /// Playback range is independent from spatial positioning points.
    var audioStartTime: Double
    var audioDuration: Double
    var isVoice: Bool

    var themeColor: Color { theme.color }
    var audioEndTime: Double { audioStartTime + audioDuration }

    init(
        id: UUID = UUID(),
        materialID: String? = nil,
        name: String,
        iconName: String,
        theme: SpatialSourceTheme,
        defaultPosition: CGPoint,
        keyPoints: [SpatialKeyPoint],
        audioStartTime: Double = 0,
        audioDuration: Double = 120,
        isVoice: Bool = false
    ) {
        self.id = id
        self.materialID = materialID
        self.name = name
        self.iconName = iconName
        self.theme = theme
        self.defaultPosition = SpatialTrajectory.clampedToUnitCircle(defaultPosition)
        self.keyPoints = keyPoints.sorted { $0.time < $1.time }
        self.audioStartTime = max(0, audioStartTime)
        self.audioDuration = max(1, audioDuration)
        self.isVoice = isVoice
    }
}

enum SpatialTrajectory {
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
        let smoothProgress = progress * progress * (3 - 2 * progress)

        return clampedToUnitCircle(
            CGPoint(
                x: start.position.x
                    + (end.position.x - start.position.x) * smoothProgress,
                y: start.position.y
                    + (end.position.y - start.position.y) * smoothProgress
            )
        )
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
}

enum SpatialTimeText {
    static func string(_ seconds: Double) -> String {
        let clamped = max(seconds, 0)
        let wholeSeconds = Int(clamped.rounded())
        return String(format: "%d:%02d", wholeSeconds / 60, wholeSeconds % 60)
    }
}
