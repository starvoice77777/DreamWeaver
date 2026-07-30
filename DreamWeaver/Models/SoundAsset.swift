import Foundation

struct SoundSource: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var symbolName: String
    var isEnabled: Bool
    var volume: Double
    var position: SpatialPosition
    var assetId: UUID?

    init(
        id: UUID = UUID(),
        name: String,
        symbolName: String,
        isEnabled: Bool = true,
        volume: Double = 0.7,
        position: SpatialPosition = .default,
        assetId: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.isEnabled = isEnabled
        self.volume = volume
        self.position = position
        self.assetId = assetId
    }
}

struct SoundAsset: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var kind: SoundAssetKind
    var durationSeconds: Int
    var symbolName: String
    var avatarColor: UInt32
    var isFavorite: Bool
    var relation: PersonRelation?
    var createdAt: Date
    var lastUsedAt: Date?

    var durationText: String {
        let m = durationSeconds / 60
        let s = durationSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

struct UsageRecord: Identifiable, Hashable, Codable {
    let id: UUID
    var totalMinutes: Int
    var weekMinutes: Int
    /// Usual bedtime display, e.g. "23:30".
    var usualBedtime: String
    var lastUsedAt: Date
    /// Demo: last 7 days sleep / usage minutes for trend.
    var sleepTrend: [Int]

    var totalHoursText: String {
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        return "\(h) 小时 \(m) 分"
    }

    var weekHoursText: String {
        let h = weekMinutes / 60
        let m = weekMinutes % 60
        if h > 0 {
            return "\(h) 小时 \(m) 分"
        }
        return "\(m) 分钟"
    }
}

struct SavedMix: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var sceneId: UUID
    var sources: [SoundSource]
    var savedAt: Date
}

enum MixPresetAuthor: String, Hashable, Codable {
    case official = "官方"
    case community = "社区"
}

/// Curated sound-mix layout that can be one-tap applied to the circle board.
struct MixPreset: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var subtitle: String
    var authorType: MixPresetAuthor
    var authorName: String
    var sources: [SoundSource]
}

