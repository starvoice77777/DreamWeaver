import Foundation

/// Recoverable service errors. Views should show message, not crash.
enum ServiceError: Error, LocalizedError, Equatable {
    case notFound(String)
    case unauthorized
    case audioResourceMissing(String)
    case processingFailed(String)
    case persistenceFailed(String)
    case invalidState(String)
    case network(String)
    case httpStatus(Int, String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .notFound(let id):
            return "未找到资源：\(id)"
        case .unauthorized:
            return "需要登录或授权后才能继续"
        case .audioResourceMissing(let name):
            return "音频资源缺失：\(name)，已跳过该轨"
        case .processingFailed(let reason):
            return "处理失败：\(reason)"
        case .persistenceFailed(let reason):
            return "保存失败：\(reason)"
        case .invalidState(let reason):
            return reason
        case .network(let reason):
            return "网络错误：\(reason)"
        case .httpStatus(let code, let detail):
            return "服务器错误（\(code)）：\(detail)"
        case .decoding(let reason):
            return "数据解析失败：\(reason)"
        }
    }

    /// Whether the app can safely continue with a local fallback or skipped resource.
    /// `false` means user action or an explicit error flow is required.
    var isRecoverable: Bool {
        switch self {
        case .audioResourceMissing, .notFound:
            return true
        case .unauthorized, .processingFailed, .persistenceFailed, .invalidState,
             .network, .httpStatus, .decoding:
            return false
        }
    }
}

enum LoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}

enum AudioLayerKind: String, Codable, Hashable {
    case environment
    case trigger
    case voice
    case ambience
}

enum ProcessingStatus: String, Codable, Hashable {
    case ready
    case processing
    case failed
    case pendingAuthorization
}

/// Pre-delete impact for library assets (maps `GET .../delete-impact`).
struct LibraryDeleteImpact: Hashable {
    struct AffectedScene: Identifiable, Hashable {
        let id: UUID
        let name: String
        let draftReferenceCount: Int
        let savedReferenceCount: Int
    }

    let assetId: UUID
    let totalReferences: Int
    let affectedScenes: [AffectedScene]
}

struct AudioTrackRef: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var symbolName: String
    var resourceName: String
    var layer: AudioLayerKind
    var loops: Bool
    /// Internal timeline automation level, not a user mix gain.
    var initialEnvelope: Double
    var defaultPosition: SpatialPosition
    /// When true, track is required for a credible demo; missing file is reported.
    var isRequired: Bool

    init(
        id: UUID = UUID(),
        name: String,
        symbolName: String,
        resourceName: String,
        layer: AudioLayerKind,
        loops: Bool = true,
        initialEnvelope: Double = 1,
        defaultPosition: SpatialPosition = .default,
        isRequired: Bool = true
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.resourceName = resourceName
        self.layer = layer
        self.loops = loops
        self.initialEnvelope = initialEnvelope
        self.defaultPosition = defaultPosition
        self.isRequired = isRequired
    }
}

struct SceneAudioManifest: Hashable, Codable {
    var tracks: [AudioTrackRef]
    /// Bundle resource for one-shot voice phrases (optional).
    var voicePhraseResourceName: String?
}

struct SeedQualityReport: Hashable, Codable {
    var clarity: String
    var noiseLevel: String
    var effectiveDurationSeconds: Int
    var recommendation: String
    var passed: Bool
}

enum SeedJobStatus: String, Codable, Hashable {
    case queued
    case processing
    case completed
    case failed
}

struct SeedJob: Identifiable, Hashable, Codable {
    var id: UUID
    var status: SeedJobStatus
    var progress: Double
    var message: String
    var resultAsset: SoundAsset?
    var previewResourceName: String?
}

struct VoiceAuthorization: Hashable, Codable {
    var confirmed: Bool
    var revocable: Bool
    var authorizationId: String?
}

struct BootstrapPayload: Hashable, Codable {
    var greeting: String
    var recommendedSceneId: UUID
    var defaultSceneId: UUID
    var nickname: String
    var isAppleSignedIn: Bool
    var isMember: Bool
}

enum AnalyticsEvent: Hashable, Codable {
    case sceneListen(sceneId: UUID)
    case sessionEnded(sceneId: UUID, durationSeconds: Int)
    case seedCreated(assetId: UUID)
    case mixEdited(sceneId: UUID)

    var typeName: String {
        switch self {
        case .sceneListen: return "scene_listen"
        case .sessionEnded: return "session_ended"
        case .seedCreated: return "seed_created"
        case .mixEdited: return "mix_edited"
        }
    }
}

struct FadePhase: Hashable, Codable {
    var layer: AudioLayerKind
    var delaySeconds: Double
    var durationSeconds: Double
}

enum DemoFadeSchedule {
    /// Accelerated demo: phrase stop → voice out → environment out.
    static let accelerated: [FadePhase] = [
        FadePhase(layer: .voice, delaySeconds: 20, durationSeconds: 6),
        FadePhase(layer: .trigger, delaySeconds: 26, durationSeconds: 6),
        FadePhase(layer: .environment, delaySeconds: 32, durationSeconds: 10),
        FadePhase(layer: .ambience, delaySeconds: 34, durationSeconds: 10)
    ]
}
