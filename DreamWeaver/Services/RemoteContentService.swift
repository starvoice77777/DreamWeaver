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
        return try await withThrowingTaskGroup(of: DreamScene.self) { group in
            for summary in summaries {
                group.addTask { [client] in
                    let detail: APIContentDTO.SceneDetail = try await client.get(
                        "/v1/scenes/\(summary.id.uuidString)",
                        authorized: false
                    )
                    return APIContentMapper.dreamScene(from: detail)
                }
            }
            var scenes: [DreamScene] = []
            scenes.reserveCapacity(summaries.count)
            for try await scene in group {
                scenes.append(scene)
            }
            // Keep server sort_order by rematching summary order.
            let byId = Dictionary(uniqueKeysWithValues: scenes.map { ($0.id, $0) })
            return summaries.compactMap { byId[$0.id] }
        }
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

    func randomGreeting() -> String {
        cachedGreeting
    }

    func persistSceneOverlay(scenes: [DreamScene]) throws {
        // Favorites / listen counts for remote users go through authenticated APIs later.
    }
}
