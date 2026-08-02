import Foundation

/// Remote companionship analytics against `/v1/analytics/*`.
/// Falls back to local store when there is no authenticated session.
@MainActor
final class RemoteAnalyticsService: AnalyticsService {
    private let client: APIClient
    private let fallback: LocalAnalyticsService

    init(client: APIClient = .shared, fallback: LocalAnalyticsService? = nil) {
        self.client = client
        self.fallback = fallback ?? LocalAnalyticsService()
    }

    func summary() async throws -> UsageRecord {
        guard KeychainTokenStore.hasSession else {
            return try await fallback.summary()
        }
        let dto: APIContentDTO.UsageSummary = try await client.get(
            "/v1/analytics/summary",
            authorized: true
        )
        return APIContentMapper.usageRecord(from: dto)
    }

    func record(_ event: AnalyticsEvent) async throws {
        guard KeychainTokenStore.hasSession else {
            try await fallback.record(event)
            return
        }
        let payload = Self.payload(from: event)
        let _: APIContentDTO.AnalyticsEventsAccepted = try await client.post(
            "/v1/analytics/events",
            body: APIContentDTO.AnalyticsEventsBatch(events: [payload]),
            authorized: true
        )
    }

    func resetDemoStats() async throws {
        // Remote aggregates are not wiped by the demo reset control; clear local fallback only.
        try await fallback.resetDemoStats()
    }

    private static func payload(from event: AnalyticsEvent) -> APIContentDTO.AnalyticsEventPayload {
        switch event {
        case .sceneListen(let sceneId):
            return APIContentDTO.AnalyticsEventPayload(
                type: event.typeName,
                scene_id: sceneId,
                asset_id: nil,
                duration_seconds: nil,
                occurred_at: nil,
                idempotency_key: nil
            )
        case .sessionEnded(let sceneId, let durationSeconds):
            return APIContentDTO.AnalyticsEventPayload(
                type: event.typeName,
                scene_id: sceneId,
                asset_id: nil,
                duration_seconds: durationSeconds,
                occurred_at: nil,
                idempotency_key: UUID().uuidString
            )
        case .seedCreated(let assetId):
            return APIContentDTO.AnalyticsEventPayload(
                type: event.typeName,
                scene_id: nil,
                asset_id: assetId,
                duration_seconds: nil,
                occurred_at: nil,
                idempotency_key: nil
            )
        case .mixEdited(let sceneId):
            return APIContentDTO.AnalyticsEventPayload(
                type: event.typeName,
                scene_id: sceneId,
                asset_id: nil,
                duration_seconds: nil,
                occurred_at: nil,
                idempotency_key: nil
            )
        }
    }
}