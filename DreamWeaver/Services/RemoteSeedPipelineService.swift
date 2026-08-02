import Foundation

/// Remote seed pipeline against `/v1/voice-authorizations` + `/v1/seeds/*`.
/// Falls back to local when there is no authenticated session.
///
/// Until Seed UI uploads real recordings, `startProcess` uploads the bundled
/// `voice_phrase_mom` sample as the source asset so the remote path can be smoked end-to-end.
@MainActor
final class RemoteSeedPipelineService: SeedPipelineService {
    private let client: APIClient
    private let library: RemoteUserLibraryService
    private let fallback: LocalSeedPipelineService

    private var authorizationId: UUID?
    private var lastDurationSeconds: Int = 3

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
        let source = try await uploadDemoSource(durationSeconds: durationSeconds)
        let dto: APIContentDTO.SeedJob = try await client.post(
            "/v1/seeds/process",
            body: APIContentDTO.SeedProcessIn(
                authorization_id: authorizationId,
                source_asset_id: source.id
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
        guard let fileURL = Bundle.main.url(forResource: "voice_phrase_mom", withExtension: "wav")
            ?? Bundle.main.url(forResource: "voice_phrase_mom", withExtension: "m4a")
        else {
            throw ServiceError.invalidState("缺少演示人声音频资源 voice_phrase_mom")
        }
        let ext = fileURL.pathExtension.lowercased()
        let contentType = ext == "wav" ? "audio/wav" : "audio/mp4"
        return try await library.uploadAudio(
            fileURL: fileURL,
            filename: "seed-source.\(ext)",
            contentType: contentType,
            kind: .seed,
            name: "种子录音素材",
            durationSeconds: max(durationSeconds, 3)
        )
    }
}
