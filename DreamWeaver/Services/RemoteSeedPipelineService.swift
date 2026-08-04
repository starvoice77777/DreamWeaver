import Foundation

/// Remote seed pipeline against `/v1/voice-authorizations` + `/v1/seeds/*`.
/// Falls back to local when there is no authenticated session.
///
/// Prefers `pendingSourceFileURL` from Seed UI when set; otherwise uploads the bundled
/// `voice_phrase_mom` sample so the remote path can still be smoked end-to-end.
@MainActor
final class RemoteSeedPipelineService: SeedPipelineService {
    private let client: APIClient
    private let library: RemoteUserLibraryService
    private let fallback: LocalSeedPipelineService

    private var authorizationId: UUID?
    private var lastDurationSeconds: Int = 3

    /// Optional real recording chosen by Seed UI. Cleared after `startProcess` uploads it.
    /// Avoids extending `SeedPipelineService` / AppState until the backend protocol lands.
    var pendingSourceFileURL: URL?
    var pendingSourceFilename: String?
    var pendingSourceContentType: String?
    /// Already-uploaded library asset used as seed source (skips re-upload).
    var pendingSourceAssetId: UUID?

    init(
        client: APIClient = .shared,
        library: RemoteUserLibraryService,
        fallback: LocalSeedPipelineService? = nil
    ) {
        self.client = client
        self.library = library
        // Default-arg expressions are nonisolated; construct on the main actor here.
        self.fallback = fallback ?? LocalSeedPipelineService()
    }

    func clearPendingSource() {
        pendingSourceFileURL = nil
        pendingSourceFilename = nil
        pendingSourceContentType = nil
        pendingSourceAssetId = nil
    }

    func analyze(durationSeconds: Int) async throws -> SeedQualityReport {
        lastDurationSeconds = durationSeconds
        guard KeychainTokenStore.hasSession else {
            return try await fallback.analyze(durationSeconds: durationSeconds)
        }
        let dto: APIContentDTO.SeedQualityReport = try await client.post(
            "/v1/seeds/analyze",
            body: APIContentDTO.SeedAnalyzeIn(duration_seconds: durationSeconds),
            authorized: true
        )
        return APIContentMapper.seedQualityReport(from: dto)
    }

    func authorize(confirmed: Bool) async throws {
        guard KeychainTokenStore.hasSession else {
            try await fallback.authorize(confirmed: confirmed)
            return
        }
        guard confirmed else { throw ServiceError.unauthorized }
        let dto: APIContentDTO.VoiceAuthorization = try await client.post(
            "/v1/voice-authorizations",
            body: APIContentDTO.VoiceAuthorizationCreate(confirmed: true),
            authorized: true
        )
        authorizationId = dto.id
    }

    func startProcess(durationSeconds: Int) async throws -> SeedJob {
        lastDurationSeconds = durationSeconds
        guard KeychainTokenStore.hasSession else {
            return try await fallback.startProcess(durationSeconds: durationSeconds)
        }
        guard let authorizationId else {
            throw ServiceError.invalidState("请先完成声音授权")
        }
        let sourceAssetId: UUID
        if let pendingSourceAssetId {
            sourceAssetId = pendingSourceAssetId
            clearPendingSource()
        } else {
            sourceAssetId = try await uploadDemoSource(durationSeconds: durationSeconds).id
        }
        let dto: APIContentDTO.SeedJob = try await client.post(
            "/v1/seeds/process",
            body: APIContentDTO.SeedProcessIn(
                authorization_id: authorizationId,
                source_asset_id: sourceAssetId
            ),
            authorized: true
        )
        return APIContentMapper.seedJob(from: dto)
    }

    func pollJob(id: UUID) async throws -> SeedJob {
        guard KeychainTokenStore.hasSession else {
            return try await fallback.pollJob(id: id)
        }
        let dto: APIContentDTO.SeedJob = try await client.get(
            "/v1/seeds/jobs/\(id.uuidString)",
            authorized: true
        )
        return APIContentMapper.seedJob(from: dto)
    }

    func finalize(jobId: UUID, name: String, relation: PersonRelation) async throws -> SoundAsset {
        guard KeychainTokenStore.hasSession else {
            return try await fallback.finalize(jobId: jobId, name: name, relation: relation)
        }
        let dto: APIContentDTO.SoundAsset = try await client.post(
            "/v1/seeds/jobs/\(jobId.uuidString)/finalize",
            body: APIContentDTO.SeedFinalizeIn(name: name, relation: relation.rawValue),
            authorized: true
        )
        var asset = APIContentMapper.soundAsset(from: dto)
        asset.relation = relation
        asset.previewResourceName = "voice_phrase_mom"
        asset.authorization = VoiceAuthorization(
            confirmed: true,
            revocable: true,
            authorizationId: authorizationId?.uuidString
        )
        return asset
    }

    private func uploadDemoSource(durationSeconds: Int) async throws -> SoundAsset {
        let source: (url: URL, filename: String, contentType: String)
        if let pending = pendingSourceFileURL {
            let filename = pendingSourceFilename ?? pending.lastPathComponent
            let contentType = pendingSourceContentType ?? mimeType(for: pending)
            source = (pending, filename, contentType)
        } else if let bundled = Bundle.main.url(forResource: "voice_phrase_mom", withExtension: "wav")
            ?? Bundle.main.url(forResource: "voice_phrase_mom", withExtension: "m4a")
        {
            let ext = bundled.pathExtension.lowercased()
            source = (bundled, "seed-source.\(ext)", ext == "wav" ? "audio/wav" : "audio/mp4")
        } else {
            throw ServiceError.invalidState("缺少种子录音素材，请先从本地选择音频")
        }

        defer { clearPendingSource() }

        let accessed = source.url.startAccessingSecurityScopedResource()
        defer {
            if accessed { source.url.stopAccessingSecurityScopedResource() }
        }

        return try await library.uploadAudio(
            fileURL: source.url,
            filename: source.filename,
            contentType: source.contentType,
            kind: .seed,
            name: "种子录音素材",
            durationSeconds: max(durationSeconds, 3)
        )
    }

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "m4a", "mp4", "aac": return "audio/mp4"
        case "mp3": return "audio/mpeg"
        case "wav": return "audio/wav"
        case "aiff", "aif": return "audio/aiff"
        case "caf": return "audio/x-caf"
        default: return "application/octet-stream"
        }
    }
}
