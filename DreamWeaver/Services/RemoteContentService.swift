import Foundation

/// Remote `ContentService` talking to FastAPI. Guest-readable endpoints need no Bearer.
@MainActor
final class RemoteContentService: ContentService {
    private let client: APIClient
    private var cachedGreeting: String = MockDataService.greetings[0]

    init(client: APIClient = .shared) {
        self.client = client
    }

    func loadBootstrap() async throws -> BootstrapPayload {
        let dto: APIContentDTO.Bootstrap = try await client.get("/v1/bootstrap", authorized: false)
        cachedGreeting = dto.greeting
        return APIContentMapper.bootstrapPayload(from: dto)
    }

    func fetchScenes() async throws -> [DreamScene] {
        let summaries: [APIContentDTO.SceneSummary] = try await client.get("/v1/scenes", authorized: false)
        let detailsByID = try await withThrowingTaskGroup(
            of: APIContentDTO.SceneDetail.self
        ) { group in
            for summary in summaries {
                let sceneID = summary.id
                group.addTask { [client, sceneID] in
                    try await client.get(
                        "/v1/scenes/\(sceneID.uuidString)",
                        authorized: false
                    )
                }
            }
            var details: [UUID: APIContentDTO.SceneDetail] = [:]
            details.reserveCapacity(summaries.count)
            for try await detail in group {
                details[detail.id] = detail
            }
            return details
        }
        // Map UI models on MainActor and keep server sort_order from summaries.
        let ordered = summaries.compactMap { detailsByID[$0.id] }.map(
            APIContentMapper.dreamScene(from:)
        )
        return MockDataService.markTopFrequentScenes(ordered)
    }

    func fetchScene(id: UUID) async throws -> DreamScene {
        let detail: APIContentDTO.SceneDetail = try await client.get(
            "/v1/scenes/\(id.uuidString)",
            authorized: false
        )
        return APIContentMapper.dreamScene(from: detail)
    }

    func fetchMixPresets(sceneStyle: SceneVisualStyle?) async throws -> [MixPreset] {
        let dtos: [APIContentDTO.MixPreset] = try await client.get("/v1/presets", authorized: false)
        let mapped = dtos.map(APIContentMapper.mixPreset(from:))
        guard let style = sceneStyle else { return mapped }
        let hint = style.rawValue
        let filtered = mapped.filter { $0.subtitle == hint || $0.subtitle.isEmpty }
        return filtered.isEmpty ? mapped : filtered
    }

    func fetchTimeline(sceneId: UUID) async throws -> APIContentDTO.SceneTimeline {
        try await client.get("/v1/scenes/\(sceneId.uuidString)/timeline", authorized: false)
    }

    func randomGreeting() -> String {
        cachedGreeting
    }

    func persistSceneOverlay(scenes: [DreamScene]) throws {
        // Favorites / listen for remote users go through RemoteUserService when authenticated.
    }
}
