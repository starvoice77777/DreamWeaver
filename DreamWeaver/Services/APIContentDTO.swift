import Foundation

/// Snake_case DTOs matching FastAPI `/v1` JSON. Mapped into app models.
enum APIContentDTO {
    struct SpatialPosition: Codable {
        let angle: Double
        let radius: Double
    }

    struct Palette: Decodable {
        let top: UInt32
        let mid: UInt32
        let bottom: UInt32
        let accent: UInt32
    }

    struct Track: Decodable {
        let id: UUID
        let name: String
        let symbol_name: String
        let layer: String
        let initial_envelope: Double
        let position: SpatialPosition
        let resource_key: String?
        let loop: Bool?
        let enabled_by_default: Bool?

        private enum CodingKeys: String, CodingKey {
            case id, name, symbol_name, layer, initial_envelope, volume
            case position, resource_key, loop, enabled_by_default
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            symbol_name = try container.decode(String.self, forKey: .symbol_name)
            layer = try container.decode(String.self, forKey: .layer)
            initial_envelope = try container.decodeIfPresent(Double.self, forKey: .initial_envelope)
                ?? container.decodeIfPresent(Double.self, forKey: .volume)
                ?? 1
            position = try container.decode(SpatialPosition.self, forKey: .position)
            resource_key = try container.decodeIfPresent(String.self, forKey: .resource_key)
            loop = try container.decodeIfPresent(Bool.self, forKey: .loop)
            enabled_by_default = try container.decodeIfPresent(Bool.self, forKey: .enabled_by_default)
        }
    }

    struct SceneSummary: Decodable {
        let id: UUID
        let name: String
        let subtitle: String
        let description: String
        let category: String
        let tags: [String]
        let palette: Palette
        let visual_style: String
        let recommended_duration_seconds: Int?
        let is_demo_playable: Bool?
        let mock_listener_count: Int?
        let sort_order: Int?
    }

    struct SceneDetail: Decodable {
        let id: UUID
        let name: String
        let subtitle: String
        let description: String
        let category: String
        let tags: [String]
        let palette: Palette
        let visual_style: String
        let recommended_duration_seconds: Int?
        let is_demo_playable: Bool?
        let mock_listener_count: Int?
        let sort_order: Int?
        let tracks: [Track]
    }

    // MARK: - Scene timeline (Stage 6 PR1; scheduler wired in PR2)

    struct VoiceBinding: Codable, Hashable {
        let kind: String
        let resource_key: String?
        let asset_id: UUID?
        let track_id: UUID?
        let track_layer: String?
    }

    struct Phrase: Codable, Hashable, Identifiable {
        let id: UUID
        let text: String
        let review_status: String
        let voice_binding: VoiceBinding
    }

    struct CueAction: Codable, Hashable {
        let type: String
        let phrase_id: UUID?
        let track_id: UUID?
        let envelope: Double?
        let fade_ms: Int?
        let angle: Double?
        let radius: Double?
        let resource_key: String?

        private enum CodingKeys: String, CodingKey {
            case type, phrase_id, track_id, envelope, volume, fade_ms, angle, radius, resource_key
        }

        init(
            type: String,
            phrase_id: UUID? = nil,
            track_id: UUID? = nil,
            envelope: Double? = nil,
            fade_ms: Int? = nil,
            angle: Double? = nil,
            radius: Double? = nil,
            resource_key: String? = nil
        ) {
            self.type = type == "set_volume" ? "set_envelope" : type
            self.phrase_id = phrase_id
            self.track_id = track_id
            self.envelope = envelope
            self.fade_ms = fade_ms
            self.angle = angle
            self.radius = radius
            self.resource_key = resource_key
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let rawType = try container.decode(String.self, forKey: .type)
            type = rawType == "set_volume" ? "set_envelope" : rawType
            phrase_id = try container.decodeIfPresent(UUID.self, forKey: .phrase_id)
            track_id = try container.decodeIfPresent(UUID.self, forKey: .track_id)
            envelope = try container.decodeIfPresent(Double.self, forKey: .envelope)
                ?? container.decodeIfPresent(Double.self, forKey: .volume)
            fade_ms = try container.decodeIfPresent(Int.self, forKey: .fade_ms)
            angle = try container.decodeIfPresent(Double.self, forKey: .angle)
            radius = try container.decodeIfPresent(Double.self, forKey: .radius)
            resource_key = try container.decodeIfPresent(String.self, forKey: .resource_key)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(type, forKey: .type)
            try container.encodeIfPresent(phrase_id, forKey: .phrase_id)
            try container.encodeIfPresent(track_id, forKey: .track_id)
            try container.encodeIfPresent(envelope, forKey: .envelope)
            try container.encodeIfPresent(fade_ms, forKey: .fade_ms)
            try container.encodeIfPresent(angle, forKey: .angle)
            try container.encodeIfPresent(radius, forKey: .radius)
            try container.encodeIfPresent(resource_key, forKey: .resource_key)
        }
    }

    struct Cue: Codable, Hashable, Identifiable {
        let id: UUID
        let at_seconds: Double?
        let progress: Double?
        let repeat_every_seconds: Double?
        let until_seconds: Double?
        let actions: [CueAction]
    }

    struct SceneTimeline: Codable, Hashable {
        let scene_id: UUID
        let version: Int
        let automation_mode: String
        let duration_hint_seconds: Int?
        let override_policy: String
        let manual_override_track_ids: [UUID]?
        let phrases: [Phrase]
        let cues: [Cue]
    }

    struct MixPreset: Decodable {
        let id: UUID
        let name: String
        let style_hint: String?
        let author_name: String
        let sources: [PresetSource]
        let scene_id: UUID?
    }

    struct PresetSource: Decodable {
        let name: String
        let symbolName: String?
        let symbol_name: String?
        let initialEnvelope: Double?
        let resourceName: String?
        let resource_name: String?
        let layer: String?
        let isEnabled: Bool?
        let position: SpatialPosition?
    }

    struct Settings: Codable {
        let reduce_motion: Bool?
        let auto_play_enabled: Bool?
        let background_play_enabled: Bool?
        let lock_screen_play_enabled: Bool?
        let animation_intensity: Double?
        let dark_mode_forced: Bool?
        let audio_quality: String?
        let notifications_enabled: Bool?
        let default_scene_id: UUID?
    }

    struct SettingsUpdate: Encodable {
        var reduce_motion: Bool?
        var auto_play_enabled: Bool?
        var background_play_enabled: Bool?
        var lock_screen_play_enabled: Bool?
        var animation_intensity: Double?
        var dark_mode_forced: Bool?
        var audio_quality: String?
        var notifications_enabled: Bool?
    }

    struct UsageSummary: Decodable {
        let id: UUID
        let total_minutes: Int
        let week_minutes: Int
        let usual_bedtime: String
        let last_used_at: Date
        let sleep_trend: [Int]
    }

    struct AnalyticsEventPayload: Encodable {
        let type: String
        let scene_id: UUID?
        let asset_id: UUID?
        let duration_seconds: Int?
        let occurred_at: Date?
        let idempotency_key: String?
    }

    struct AnalyticsEventsBatch: Encodable {
        let events: [AnalyticsEventPayload]
    }

    struct AnalyticsEventsAccepted: Decodable {
        let accepted: Int
        let skipped_duplicates: Int?
    }

    struct Bootstrap: Decodable {
        let greeting: String
        let default_scene_id: UUID
        let scenes: [SceneSummary]
        let settings: Settings
        let server_time: Date?
        let api_version: String?
    }

    struct AuthTokens: Decodable {
        let access_token: String
        let refresh_token: String
        let token_type: String?
        let expires_in: Int?
        let user_id: UUID
        let nickname: String
    }

    struct SceneStatePatch: Encodable {
        var is_favorite: Bool?
        var mark_opened: Bool = false
    }

    struct SceneState: Decodable {
        let scene_id: UUID
        let is_favorite: Bool
        let last_opened_at: Date?
        let listen_count: Int
    }

    struct PrivateSceneSummary: Decodable, Hashable, Identifiable {
        let id: UUID
        let name: String
        let subtitle: String
        let description: String
        let category: String
        let tags: [String]
        let visual_style: String
        let source_scene_id: UUID?
        let has_saved_version: Bool
        let saved_version: Int
        let saved_at: Date?
        let updated_at: Date
    }

    struct PrivateSceneDetail: Decodable {
        let id: UUID
        let name: String
        let subtitle: String
        let description: String
        let category: String
        let tags: [String]
        let visual_style: String
        let source_scene_id: UUID?
        let has_saved_version: Bool
        let saved_version: Int
        let saved_at: Date?
        let updated_at: Date
        let palette: [String: Int]?
        let recommended_duration_seconds: Int?
        let draft_sources: [PresetSource]?
        let saved_sources: [PresetSource]?
        let draft_timeline: SceneTimeline?
        let saved_timeline: SceneTimeline?
        /// User create-mode document (`scene_composition_v1`); optional until Create Tab lands.
        let draft_composition: SceneComposition?
        let saved_composition: SceneComposition?
    }

    /// Sparse keyframe composition for Create mode. Playback interpolator is separate.
    struct SceneComposition: Codable {
        let schema: String
        let version: Int
        let duration_seconds: Double?
        let tracks: [CompositionTrack]
        /// Optional text-cue track for Create editor; preserved by server validate_composition.
        var text_cues: [CompositionTextCue]? = nil
    }

    struct CompositionTextCue: Codable, Equatable {
        let id: UUID
        let time: Double
        let text: String
    }

    struct CompositionTrack: Codable {
        let id: UUID
        let asset_id: UUID?
        let resource_key: String?
        let layer: String?
        let loop: Bool?
        let start_seconds: Double
        let end_seconds: Double
        let source_duration_seconds: Double?
        let keyframes: [CompositionKeyframe]
    }

    struct CompositionKeyframe: Codable {
        let t: Double
        let angle: Double
        let radius: Double
    }

    struct PrivateSceneCreate: Encodable {
        let name: String
        let subtitle: String
        let description: String
        let category: String
        let tags: [String]
        let palette: [String: UInt32]?
        let visual_style: String
        let sources: [MixSourcePayload]
        /// Optional create-mode document (`scene_composition_v1`).
        var composition: SceneComposition? = nil
    }

    struct PrivateSceneDraftUpdate: Encodable {
        var name: String?
        var sources: [MixSourcePayload]?
        var draft_timeline: SceneTimeline?
        var draft_composition: SceneComposition?
    }

    struct MixSourcePayload: Encodable {
        let name: String
        let symbolName: String
        let layer: String
        let initialEnvelope: Double
        let position: SpatialPosition
        let resourceName: String?
        let isEnabled: Bool
        let assetId: UUID?
    }

    struct SoundAsset: Decodable {
        let id: UUID
        let name: String
        let kind: String
        let symbol_name: String
        let duration_seconds: Int
        let content_type: String
        let byte_size: Int
        let is_favorite: Bool
        let processing_status: String
        let created_at: Date
        let updated_at: Date
    }

    struct SoundAssetPatch: Encodable {
        var name: String?
        var symbol_name: String?
        var is_favorite: Bool?
    }

    struct UploadCreate: Encodable {
        let filename: String
        let content_type: String
        let byte_size: Int
        let kind: String
        let name: String?
        let duration_seconds: Int
    }

    struct UploadSession: Decodable {
        let upload_id: UUID
        let put_url: String
        let storage_key: String
        let required_headers: [String: String]
        let expires_at: Date
        let max_byte_size: Int
    }

    struct DeleteImpact: Decodable {
        let asset_id: UUID
        let affected_scenes: [AffectedScene]
        let total_references: Int

        struct AffectedScene: Decodable {
            let id: UUID
            let name: String
            let draft_reference_count: Int
            let saved_reference_count: Int
        }
    }

    struct DeleteAssetResult: Decodable {
        let asset_id: UUID
        let deleted: Bool
        let scrubbed_scene_ids: [UUID]
        let storage_deleted: Bool
    }

    struct PlaybackURL: Decodable {
        let asset_id: UUID
        let url: String
        let expires_at: Date
    }

    struct Home: Decodable {
        let greeting_scene_id: UUID
        let recommended: [SceneSummary]
        let recent: [SceneSummary]
        let favorites: [SceneSummary]
        let private_scenes: [PrivateSceneSummary]
    }
}

enum APIContentMapper {
    static func dreamScene(from detail: APIContentDTO.SceneDetail) -> DreamScene {
        let sources = detail.tracks.map(soundSource(from:))
        let manifest = SceneAudioManifest(
            tracks: detail.tracks.map { track in
                AudioTrackRef(
                    id: track.id,
                    name: track.name,
                    symbolName: track.symbol_name,
                    resourceName: track.resource_key ?? "",
                    layer: audioLayer(track.layer),
                    loops: track.loop ?? true,
                    initialEnvelope: track.initial_envelope,
                    defaultPosition: SpatialPosition(
                        angle: track.position.angle,
                        radius: track.position.radius
                    ),
                    isRequired: true
                )
            },
            voicePhraseResourceName: detail.tracks.first(where: { $0.layer == "voice" })?.resource_key
        )

        return DreamScene(
            id: detail.id,
            name: detail.name,
            subtitle: detail.subtitle,
            description: detail.description,
            category: sceneCategory(detail.category),
            tags: detail.tags,
            palette: ScenePalette(
                top: detail.palette.top,
                mid: detail.palette.mid,
                bottom: detail.palette.bottom,
                accent: detail.palette.accent
            ),
            soundSources: sources,
            isFavorite: false,
            isFrequentlyUsed: false,
            listenCount: detail.mock_listener_count ?? 0,
            mockListenerCount: detail.mock_listener_count ?? 0,
            visualStyle: visualStyle(detail.visual_style),
            isDemoPlayable: detail.is_demo_playable ?? !sources.isEmpty,
            audioManifest: manifest
        )
    }

    static func dreamSceneSummary(_ summary: APIContentDTO.SceneSummary) -> DreamScene {
        DreamScene(
            id: summary.id,
            name: summary.name,
            subtitle: summary.subtitle,
            description: summary.description,
            category: sceneCategory(summary.category),
            tags: summary.tags,
            palette: ScenePalette(
                top: summary.palette.top,
                mid: summary.palette.mid,
                bottom: summary.palette.bottom,
                accent: summary.palette.accent
            ),
            soundSources: [],
            isFavorite: false,
            isFrequentlyUsed: false,
            listenCount: summary.mock_listener_count ?? 0,
            mockListenerCount: summary.mock_listener_count ?? 0,
            visualStyle: visualStyle(summary.visual_style),
            isDemoPlayable: summary.is_demo_playable ?? false,
            audioManifest: nil
        )
    }

    static func mixPreset(from dto: APIContentDTO.MixPreset) -> MixPreset {
        MixPreset(
            id: dto.id,
            title: dto.name,
            subtitle: dto.style_hint ?? "",
            authorType: .official,
            authorName: dto.author_name,
            sources: dto.sources.map(soundSource(from:)),
            sceneId: dto.scene_id,
            styleHint: dto.style_hint
        )
    }

    static func usageRecord(from dto: APIContentDTO.UsageSummary) -> UsageRecord {
        UsageRecord(
            id: dto.id,
            totalMinutes: dto.total_minutes,
            weekMinutes: dto.week_minutes,
            usualBedtime: dto.usual_bedtime,
            lastUsedAt: dto.last_used_at,
            sleepTrend: dto.sleep_trend
        )
    }

    static func bootstrapPayload(from dto: APIContentDTO.Bootstrap) -> BootstrapPayload {
        BootstrapPayload(
            greeting: dto.greeting,
            recommendedSceneId: dto.default_scene_id,
            defaultSceneId: dto.default_scene_id,
            nickname: "夜行者",
            isAppleSignedIn: KeychainTokenStore.hasSession,
            isMember: true
        )
    }

    static func mixSourcePayload(from source: SoundSource) -> APIContentDTO.MixSourcePayload {
        APIContentDTO.MixSourcePayload(
            name: source.name,
            symbolName: source.symbolName,
            layer: source.layer.rawValue,
            initialEnvelope: source.initialEnvelope,
            position: APIContentDTO.SpatialPosition(
                angle: source.position.angle,
                radius: source.position.radius
            ),
            resourceName: source.resourceName,
            isEnabled: source.isEnabled,
            assetId: source.assetId
        )
    }

    static func soundAsset(from dto: APIContentDTO.SoundAsset) -> SoundAsset {
        SoundAsset(
            id: dto.id,
            name: dto.name,
            kind: soundAssetKind(dto.kind),
            durationSeconds: dto.duration_seconds,
            symbolName: dto.symbol_name,
            avatarColor: 0x7A90B8,
            isFavorite: dto.is_favorite,
            relation: nil,
            createdAt: dto.created_at,
            lastUsedAt: dto.updated_at,
            previewResourceName: nil,
            processingStatus: processingStatus(dto.processing_status),
            authorization: nil
        )
    }

    static func libraryDeleteImpact(from dto: APIContentDTO.DeleteImpact) -> LibraryDeleteImpact {
        LibraryDeleteImpact(
            assetId: dto.asset_id,
            totalReferences: dto.total_references,
            affectedScenes: dto.affected_scenes.map {
                LibraryDeleteImpact.AffectedScene(
                    id: $0.id,
                    name: $0.name,
                    draftReferenceCount: $0.draft_reference_count,
                    savedReferenceCount: $0.saved_reference_count
                )
            }
        )
    }

    private static func soundAssetKind(_ raw: String) -> SoundAssetKind {
        switch raw.lowercased() {
        case "voice": return .seed
        case "official": return .community
        default: return .recording
        }
    }

    static func apiSoundKind(from kind: SoundAssetKind) -> String {
        switch kind {
        case .seed: return "voice"
        case .community: return "official"
        case .recording: return "life"
        }
    }

    private static func processingStatus(_ raw: String) -> ProcessingStatus {
        ProcessingStatus(rawValue: raw) ?? .ready
    }

    static func paletteDict(from palette: ScenePalette) -> [String: UInt32] {
        [
            "top": palette.top,
            "mid": palette.mid,
            "bottom": palette.bottom,
            "accent": palette.accent,
        ]
    }

    private static func soundSource(from track: APIContentDTO.Track) -> SoundSource {
        SoundSource(
            id: track.id,
            name: track.name,
            symbolName: track.symbol_name,
            isEnabled: track.enabled_by_default ?? true,
            initialEnvelope: track.initial_envelope,
            position: SpatialPosition(angle: track.position.angle, radius: track.position.radius),
            assetId: nil,
            resourceName: track.resource_key,
            layer: audioLayer(track.layer)
        )
    }

    private static func soundSource(from source: APIContentDTO.PresetSource) -> SoundSource {
        let symbol = source.symbolName ?? source.symbol_name ?? "waveform"
        let resource = source.resourceName ?? source.resource_name
        let layer = audioLayer(source.layer ?? "environment")
        let position: SpatialPosition
        if let p = source.position {
            position = SpatialPosition(angle: p.angle, radius: p.radius)
        } else {
            position = .default
        }
        return SoundSource(
            name: source.name,
            symbolName: symbol,
            isEnabled: source.isEnabled ?? true,
            initialEnvelope: source.initialEnvelope ?? 1,
            position: position,
            resourceName: resource,
            layer: layer
        )
    }

    private static func audioLayer(_ raw: String) -> AudioLayerKind {
        AudioLayerKind(rawValue: raw) ?? .environment
    }

    private static func visualStyle(_ raw: String) -> SceneVisualStyle {
        SceneVisualStyle(rawValue: raw) ?? .longRoad
    }

    private static func sceneCategory(_ raw: String) -> SceneCategory {
        if let byChinese = SceneCategory(rawValue: raw) {
            return byChinese
        }
        switch raw.lowercased() {
        case "companion": return .companion
        case "nature": return .nature
        case "rainynight", "rainy_night", "rain": return .rainyNight
        case "ocean": return .ocean
        case "forest": return .forest
        case "voice": return .voice
        case "breath": return .breath
        case "lightmusic", "light_music": return .lightMusic
        case "whisper": return .whisper
        case "frequent": return .frequent
        case "favorites", "favorite": return .favorites
        default: return .nature
        }
    }
}
