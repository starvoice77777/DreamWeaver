import Foundation

struct SoundSource: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var symbolName: String
    var isEnabled: Bool
    /// Internal scene automation level. User-controlled loudness is derived
    /// solely from `position.radius`.
    var initialEnvelope: Double
    var position: SpatialPosition
    var assetId: UUID?
    /// Bundle resource name without forcing extension resolution in UI.
    var resourceName: String?
    var layer: AudioLayerKind

    init(
        id: UUID = UUID(),
        name: String,
        symbolName: String,
        isEnabled: Bool = true,
        initialEnvelope: Double = 1,
        position: SpatialPosition = .default,
        assetId: UUID? = nil,
        resourceName: String? = nil,
        layer: AudioLayerKind = .environment
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.isEnabled = isEnabled
        self.initialEnvelope = min(max(initialEnvelope, 0), 1)
        self.position = position
        self.assetId = assetId
        self.resourceName = resourceName
        self.layer = layer
    }

    enum CodingKeys: String, CodingKey {
        case id, name, symbolName, isEnabled, initialEnvelope, position, assetId, resourceName, layer
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        symbolName = try c.decode(String.self, forKey: .symbolName)
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        // Legacy `volume` fields are ignored by this decoder. Old personal
        // mixes therefore adopt the new radius-driven loudness model.
        initialEnvelope = try c.decodeIfPresent(Double.self, forKey: .initialEnvelope) ?? 1
        position = try c.decodeIfPresent(SpatialPosition.self, forKey: .position) ?? .default
        assetId = try c.decodeIfPresent(UUID.self, forKey: .assetId)
        resourceName = try c.decodeIfPresent(String.self, forKey: .resourceName)
        layer = try c.decodeIfPresent(AudioLayerKind.self, forKey: .layer) ?? .environment
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
    var previewResourceName: String?
    var processingStatus: ProcessingStatus
    var authorization: VoiceAuthorization?

    var durationText: String {
        let m = durationSeconds / 60
        let s = durationSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    init(
        id: UUID,
        name: String,
        kind: SoundAssetKind,
        durationSeconds: Int,
        symbolName: String,
        avatarColor: UInt32,
        isFavorite: Bool,
        relation: PersonRelation?,
        createdAt: Date,
        lastUsedAt: Date?,
        previewResourceName: String? = nil,
        processingStatus: ProcessingStatus = .ready,
        authorization: VoiceAuthorization? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.durationSeconds = durationSeconds
        self.symbolName = symbolName
        self.avatarColor = avatarColor
        self.isFavorite = isFavorite
        self.relation = relation
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.previewResourceName = previewResourceName
        self.processingStatus = processingStatus
        self.authorization = authorization
    }

    enum CodingKeys: String, CodingKey {
        case id, name, kind, durationSeconds, symbolName, avatarColor
        case isFavorite, relation, createdAt, lastUsedAt
        case previewResourceName, processingStatus, authorization
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        kind = try c.decode(SoundAssetKind.self, forKey: .kind)
        durationSeconds = try c.decode(Int.self, forKey: .durationSeconds)
        symbolName = try c.decode(String.self, forKey: .symbolName)
        avatarColor = try c.decode(UInt32.self, forKey: .avatarColor)
        isFavorite = try c.decode(Bool.self, forKey: .isFavorite)
        relation = try c.decodeIfPresent(PersonRelation.self, forKey: .relation)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        lastUsedAt = try c.decodeIfPresent(Date.self, forKey: .lastUsedAt)
        previewResourceName = try c.decodeIfPresent(String.self, forKey: .previewResourceName)
        processingStatus = try c.decodeIfPresent(ProcessingStatus.self, forKey: .processingStatus) ?? .ready
        authorization = try c.decodeIfPresent(VoiceAuthorization.self, forKey: .authorization)
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
    /// Official catalog scene this preset belongs to (remote `scene_id`).
    var sceneId: UUID? = nil
    /// Matches `SceneVisualStyle.rawValue` when present (remote `style_hint`).
    var styleHint: String? = nil
}
