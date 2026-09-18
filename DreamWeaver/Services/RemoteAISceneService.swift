import Foundation

/// Authenticated access to `/v1/ai/scene-assist`.
@MainActor
final class RemoteAISceneService {
    static let requestTimeout: TimeInterval = 600

    private let client: APIClient
    private let requestTimeout: TimeInterval

    init(
        client: APIClient = .shared,
        requestTimeout: TimeInterval = RemoteAISceneService.requestTimeout
    ) {
        self.client = client
        self.requestTimeout = requestTimeout
    }

    func generate(
        selectedSources: [AISceneDTO.SelectedSource],
        options: AISceneDTO.Options = .init()
    ) async throws -> AISceneDTO.GenerateResult {
        try await client.post(
            "/v1/ai/scene-assist/generate",
            body: AISceneDTO.GenerateRequest(
                selectedSources: selectedSources,
                options: options
            ),
            authorized: true,
            timeoutInterval: requestTimeout
        )
    }

    func adjust(
        selectedSources: [AISceneDTO.SelectedSource],
        scene: AISceneDTO.SceneMetadata,
        instruction: String,
        options: AISceneDTO.Options = .init()
    ) async throws -> AISceneDTO.AdjustResult {
        try await client.post(
            "/v1/ai/scene-assist/adjust",
            body: AISceneDTO.AdjustRequest(
                selectedSources: selectedSources,
                scene: scene,
                instruction: instruction,
                options: options
            ),
            authorized: true,
            timeoutInterval: requestTimeout
        )
    }
}
