import Foundation

/// Wire contracts for the authenticated AI scene-assist endpoints.
enum AISceneDTO {
    nonisolated enum Layer: String, Codable, Sendable {
        case environment
        case ambience
        case trigger
        case voice
    }

    nonisolated struct SelectedSource: Codable, Sendable {
        let sourceID: UUID
        let resourceKey: String
        let name: String
        let description: String
        let layer: Layer
        let loop: Bool
        let durationSeconds: Double
        let defaultVolume: Double
        let angle: Double
        let radius: Double

        enum CodingKeys: String, CodingKey {
            case sourceID = "source_id"
            case resourceKey = "resource_key"
            case name, description, layer, loop
            case durationSeconds = "duration_seconds"
            case defaultVolume = "default_volume"
            case angle, radius
        }
    }

    nonisolated struct Options: Codable, Sendable {
        let sceneIntent: String?
        let durationSeconds: Double?
        let language: String
        let constraints: [String]

        init(
            sceneIntent: String? = nil,
            durationSeconds: Double? = nil,
            language: String = "zh-CN",
            constraints: [String] = []
        ) {
            self.sceneIntent = sceneIntent
            self.durationSeconds = durationSeconds
            self.language = language
            self.constraints = constraints
        }

        enum CodingKeys: String, CodingKey {
            case sceneIntent = "scene_intent"
            case durationSeconds = "duration_seconds"
            case language, constraints
        }
    }

    nonisolated struct GenerateRequest: Encodable, Sendable {
        let selectedSources: [SelectedSource]
        let options: Options

        init(selectedSources: [SelectedSource], options: Options = Options()) {
            self.selectedSources = selectedSources
            self.options = options
        }

        enum CodingKeys: String, CodingKey {
            case selectedSources = "selected_sources"
            case options
        }
    }

    /// The backend may add presentation metadata; the editor only requires these stable fields.
    nonisolated struct SceneMetadata: Codable, Sendable {
        let name: String?
        let subtitle: String?
        let description: String?
        let composition: APIContentDTO.SceneComposition?

        init(
            name: String?,
            subtitle: String? = nil,
            description: String? = nil,
            composition: APIContentDTO.SceneComposition? = nil
        ) {
            self.name = name
            self.subtitle = subtitle
            self.description = description
            self.composition = composition
        }
    }

    nonisolated struct GenerateResult: Decodable, Sendable {
        let scene: SceneMetadata
        let composition: APIContentDTO.SceneComposition
        let validationWarnings: [String]

        enum CodingKeys: String, CodingKey {
            case scene, composition
            case validationWarnings = "validation_warnings"
        }
    }

    nonisolated struct AdjustRequest: Encodable, Sendable {
        let selectedSources: [SelectedSource]
        let scene: SceneMetadata
        let instruction: String
        let options: Options

        init(
            selectedSources: [SelectedSource],
            scene: SceneMetadata,
            instruction: String,
            options: Options = Options()
        ) {
            self.selectedSources = selectedSources
            self.scene = scene
            self.instruction = instruction
            self.options = options
        }

        enum CodingKeys: String, CodingKey {
            case selectedSources = "selected_sources"
            case scene, instruction, options
        }
    }

    nonisolated struct AdjustResult: Decodable, Sendable {
        let scene: SceneMetadata
        let composition: APIContentDTO.SceneComposition
        let changeSummary: [String]
        let validationWarnings: [String]

        enum CodingKeys: String, CodingKey {
            case scene, composition
            case changeSummary = "change_summary"
            case validationWarnings = "validation_warnings"
        }
    }
}
