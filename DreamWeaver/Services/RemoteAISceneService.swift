import Foundation

/// Authenticated access to `/v1/ai/scene-assist`.
@MainActor
final class RemoteAISceneService {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
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
            authorized: true
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
            authorized: true
        )
    }
}
