import Foundation

/// Snake_case DTOs matching FastAPI `/v1` JSON. Mapped into app models.
enum APIContentDTO {
    struct SpatialPosition: Decodable {
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
        let volume: Double
        let position: SpatialPosition
        let resource_key: String?
        let loop: Bool?
        let enabled_by_default: Bool?
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
        let volume: Double?
        let resourceName: String?
        let resource_name: String?
        let layer: String?
        let isEnabled: Bool?
        let position: SpatialPosition?
    }

    struct Settings: Decodable {
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
                    defaultVolume: track.volume,
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
            listenCount: 0,
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
            listenCount: 0,
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
            sources: dto.sources.map(soundSource(from:))
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

    private static func soundSource(from track: APIContentDTO.Track) -> SoundSource {
        SoundSource(
            id: track.id,
            name: track.name,
            symbolName: track.symbol_name,
            isEnabled: track.enabled_by_default ?? true,
            volume: track.volume,
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
            volume: source.volume ?? 0.7,
            position: position,
            resourceName: resource,
            layer: layer
        )
    }

    private static func audioLayer(_ raw: String) -> AudioLayerKind {
        AudioLayerKind(rawValue: raw) ?? .environment
    }

    private static func visualStyle(_ raw: String) -> SceneVisualStyle {
        SceneVisualStyle(rawValue: raw) ?? .warmLamp
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
