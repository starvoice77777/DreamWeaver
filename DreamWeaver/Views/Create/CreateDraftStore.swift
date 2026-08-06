import Combine
import Foundation

/// Persisted Create-tab draft so「保存草稿」can be reopened from the hub.
struct CreateSceneDraft: Identifiable, Codable, Equatable {
    var id: UUID
    /// Linked remote private scene when cloud sync succeeded.
    var privateSceneId: UUID?
    var name: String
    var sourceSceneId: UUID?
    var sourceSceneSubtitle: String?
    var soundSources: [SpatialEditorSource]
    var textCues: [SpatialTextCue]
    /// Optional for backward compatibility with locally saved v1 drafts.
    var durationSeconds: Double? = nil
    var updatedAt: Date
}

@MainActor
final class CreateDraftStore: ObservableObject {
    static let shared = CreateDraftStore()

    @Published private(set) var drafts: [CreateSceneDraft] = []

    private let defaults = UserDefaults.standard
    private let key = "dw.create.drafts.v1"
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private init() {
        reload()
    }

    func reload() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? decoder.decode([CreateSceneDraft].self, from: data) else {
            drafts = []
            return
        }
        drafts = decoded.sorted { $0.updatedAt > $1.updatedAt }
    }

    func upsert(_ draft: CreateSceneDraft) throws {
        var next = drafts.filter { $0.id != draft.id }
        next.insert(draft, at: 0)
        next.sort { $0.updatedAt > $1.updatedAt }
        try persist(next)
        drafts = next
    }

    func delete(id: UUID) {
        let next = drafts.filter { $0.id != id }
        try? persist(next)
        drafts = next
    }

    func draft(id: UUID) -> CreateSceneDraft? {
        drafts.first { $0.id == id }
    }

    private func persist(_ value: [CreateSceneDraft]) throws {
        do {
            let data = try encoder.encode(value)
            defaults.set(data, forKey: key)
        } catch {
            throw ServiceError.persistenceFailed(error.localizedDescription)
        }
    }
}
