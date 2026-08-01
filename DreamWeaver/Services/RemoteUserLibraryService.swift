import Foundation

/// Remote user sound library against `/v1/uploads` + `/v1/library/assets`.
/// Falls back to a local library when there is no authenticated session.
@MainActor
final class RemoteUserLibraryService: UserLibraryService {
    private let client: APIClient
    private let fallback: LocalUserLibraryService
    private let session: URLSession

    init(
        client: APIClient = .shared,
        fallback: LocalUserLibraryService = LocalUserLibraryService(),
        session: URLSession = .shared
    ) {
        self.client = client
        self.fallback = fallback
        self.session = session
    }

    func fetchAssets() async throws -> [SoundAsset] {
        guard KeychainTokenStore.hasSession else {
            return try await fallback.fetchAssets()
        }
        let dtos: [APIContentDTO.SoundAsset] = try await client.get(
            "/v1/library/assets",
            authorized: true
        )
        return dtos.map(APIContentMapper.soundAsset(from:))
    }

    /// Metadata sync for an existing remote asset. Creating brand-new audio still needs `uploadAudio`.
    func upsert(_ asset: SoundAsset) async throws {
        guard KeychainTokenStore.hasSession else {
            try await fallback.upsert(asset)
            return
        }
        do {
            let _: APIContentDTO.SoundAsset = try await client.patch(
                "/v1/library/assets/\(asset.id.uuidString)",
                body: APIContentDTO.SoundAssetPatch(
                    name: asset.name,
                    symbol_name: asset.symbolName,
                    is_favorite: asset.isFavorite
                ),
                authorized: true
            )
        } catch ServiceError.notFound {
            // Local-only / not yet uploaded — keep optimistic UI; Seed upload will create remotely.
            return
        }
    }

    func delete(id: UUID) async throws {
        guard KeychainTokenStore.hasSession else {
            try await fallback.delete(id: id)
            return
        }
        let _: APIContentDTO.DeleteAssetResult = try await client.deleteJSON(
            "/v1/library/assets/\(id.uuidString)",
            authorized: true
        )
    }

    func deleteImpact(id: UUID) async throws -> LibraryDeleteImpact {
        guard KeychainTokenStore.hasSession else {
            return try await fallback.deleteImpact(id: id)
        }
        let dto: APIContentDTO.DeleteImpact = try await client.get(
            "/v1/library/assets/\(id.uuidString)/delete-impact",
            authorized: true
        )
        return APIContentMapper.libraryDeleteImpact(from: dto)
    }

    func toggleFavorite(id: UUID) async throws -> SoundAsset {
        guard KeychainTokenStore.hasSession else {
            return try await fallback.toggleFavorite(id: id)
        }
        let dto: APIContentDTO.SoundAsset = try await client.postEmpty(
            "/v1/library/assets/\(id.uuidString)/favorite",
            authorized: true
        )
        return APIContentMapper.soundAsset(from: dto)
    }

    func rename(id: UUID, name: String) async throws {
        guard KeychainTokenStore.hasSession else {
            try await fallback.rename(id: id, name: name)
            return
        }
        let _: APIContentDTO.SoundAsset = try await client.patch(
            "/v1/library/assets/\(id.uuidString)",
            body: APIContentDTO.SoundAssetPatch(name: name),
            authorized: true
        )
    }

    func resetToFixture() async throws {
        // Remote catalog is server-owned; reset only the local fallback cache used when logged out.
        try await fallback.resetToFixture()
    }

    // MARK: - Presigned upload (for Seed / import UI)

    func uploadAudio(
        fileURL: URL,
        filename: String,
        contentType: String,
        kind: SoundAssetKind,
        name: String?,
        durationSeconds: Int
    ) async throws -> SoundAsset {
        guard KeychainTokenStore.hasSession else {
            throw ServiceError.unauthorized
        }
        let data = try Data(contentsOf: fileURL)
        let sessionDTO: APIContentDTO.UploadSession = try await client.post(
            "/v1/uploads",
            body: APIContentDTO.UploadCreate(
                filename: filename,
                content_type: contentType,
                byte_size: data.count,
                kind: APIContentMapper.apiSoundKind(from: kind),
                name: name,
                duration_seconds: durationSeconds
            ),
            authorized: true
        )
        try await putObject(urlString: sessionDTO.put_url, data: data, headers: sessionDTO.required_headers)
        let asset: APIContentDTO.SoundAsset = try await client.postEmpty(
            "/v1/uploads/\(sessionDTO.upload_id.uuidString)/complete?duration_seconds=\(durationSeconds)",
            authorized: true
        )
        return APIContentMapper.soundAsset(from: asset)
    }

    func playbackURL(assetId: UUID) async throws -> URL {
        let dto: APIContentDTO.PlaybackURL = try await client.get(
            "/v1/library/assets/\(assetId.uuidString)/playback-url",
            authorized: true
        )
        guard let url = URL(string: dto.url) else {
            throw ServiceError.invalidState("无效播放地址")
        }
        return url
    }

    private func putObject(urlString: String, data: Data, headers: [String: String]) async throws {
        guard let url = URL(string: urlString) else {
            throw ServiceError.invalidState("无效上传地址")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = data
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw ServiceError.httpStatus(code, "对象存储上传失败")
        }
    }
}
