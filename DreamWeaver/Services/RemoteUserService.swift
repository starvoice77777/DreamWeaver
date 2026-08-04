import Foundation

/// Authenticated user APIs: home, favorites, settings, explicit private-scene save.
@MainActor
final class RemoteUserService {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    func fetchHome() async throws -> APIContentDTO.Home {
        try await client.get("/v1/home", authorized: true)
    }

    func fetchSettings() async throws -> APIContentDTO.Settings {
        try await client.get("/v1/users/me/settings", authorized: true)
    }

    func updateSettings(_ body: APIContentDTO.SettingsUpdate) async throws -> APIContentDTO.Settings {
        try await client.put("/v1/users/me/settings", body: body, authorized: true)
    }

    func patchSceneState(
        sceneId: UUID,
        isFavorite: Bool? = nil,
        markOpened: Bool = false
    ) async throws -> APIContentDTO.SceneState {
        try await client.patch(
            "/v1/users/me/scene-states/\(sceneId.uuidString)",
            body: APIContentDTO.SceneStatePatch(is_favorite: isFavorite, mark_opened: markOpened),
            authorized: true
        )
    }

    func listPrivateScenes() async throws -> [APIContentDTO.PrivateSceneSummary] {
        try await client.get("/v1/users/me/scenes", authorized: true)
    }

    func fetchPrivateScene(id: UUID) async throws -> APIContentDTO.PrivateSceneDetail {
        try await client.get("/v1/users/me/scenes/\(id.uuidString)", authorized: true)
    }

    func copyOfficialScene(sceneId: UUID) async throws -> APIContentDTO.PrivateSceneDetail {
        try await client.postEmpty(
            "/v1/scenes/\(sceneId.uuidString)/copy",
            authorized: true
        )
    }

    func createPrivateScene(_ body: APIContentDTO.PrivateSceneCreate) async throws -> APIContentDTO.PrivateSceneDetail {
        try await client.post("/v1/users/me/scenes", body: body, authorized: true)
    }

    func updatePrivateDraft(
        sceneId: UUID,
        body: APIContentDTO.PrivateSceneDraftUpdate
    ) async throws -> APIContentDTO.PrivateSceneDetail {
        try await client.put(
            "/v1/users/me/scenes/\(sceneId.uuidString)/draft",
            body: body,
            authorized: true
        )
    }

    /// Persist Create-tab composition as a private-scene **draft** (does not publish saved version).
    func upsertCompositionDraft(
        privateSceneId: UUID?,
        name: String,
        subtitle: String,
        sourceSceneId: UUID?,
        composition: APIContentDTO.SceneComposition
    ) async throws -> APIContentDTO.PrivateSceneDetail {
        if let privateSceneId {
            return try await updatePrivateDraft(
                sceneId: privateSceneId,
                body: APIContentDTO.PrivateSceneDraftUpdate(
                    name: name,
                    sources: nil,
                    draft_timeline: nil,
                    draft_composition: composition
                )
            )
        }
        return try await createPrivateScene(
            APIContentDTO.PrivateSceneCreate(
                name: name,
                subtitle: subtitle,
                description: "",
                category: "personal",
                tags: [],
                palette: nil,
                visual_style: "custom",
                sources: [],
                composition: composition
            )
        )
    }

    /// Explicit save: draft → reusable saved version. Call only on user confirm.
    func savePrivateScene(id: UUID) async throws -> APIContentDTO.PrivateSceneDetail {
        try await client.postEmpty(
            "/v1/users/me/scenes/\(id.uuidString)/save",
            authorized: true
        )
    }

    func deletePrivateScene(id: UUID) async throws {
        try await client.delete("/v1/users/me/scenes/\(id.uuidString)", authorized: true)
    }

    /// Create (or refresh draft of) a private scene from the current mix, then explicit-save.
    func createAndSaveMix(
        name: String,
        scene: DreamScene,
        sources: [SoundSource]
    ) async throws -> APIContentDTO.PrivateSceneDetail {
        let payloads = sources.map(APIContentMapper.mixSourcePayload(from:))
        let created = try await createPrivateScene(
            APIContentDTO.PrivateSceneCreate(
                name: name,
                subtitle: scene.subtitle,
                description: scene.description,
                category: "personal",
                tags: scene.tags,
                palette: APIContentMapper.paletteDict(from: scene.palette),
                visual_style: scene.visualStyle.rawValue,
                sources: payloads
            )
        )
        return try await savePrivateScene(id: created.id)
    }

    /// Update an existing private draft from current sources, then explicit-save.
    func updateDraftAndSave(
        privateSceneId: UUID,
        name: String?,
        sources: [SoundSource]
    ) async throws -> APIContentDTO.PrivateSceneDetail {
        let payloads = sources.map(APIContentMapper.mixSourcePayload(from:))
        _ = try await updatePrivateDraft(
            sceneId: privateSceneId,
            body: APIContentDTO.PrivateSceneDraftUpdate(name: name, sources: payloads)
        )
        return try await savePrivateScene(id: privateSceneId)
    }
}
