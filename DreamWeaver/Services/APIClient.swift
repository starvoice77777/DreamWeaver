import Foundation

/// Thin HTTP client for DreamWeaver `/v1` APIs.
actor APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private var baseURL: URL
    private var isRefreshing = false

    init(baseURL: URL = ServiceBackendConfig.remoteBaseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: value) { return date }
            let basic = ISO8601DateFormatter()
            basic.formatOptions = [.withInternetDateTime]
            if let date = basic.date(from: value) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unrecognized date: \(value)"
            )
        }
        self.decoder = decoder
        self.encoder = JSONEncoder()
    }

    func setBaseURL(_ url: URL) {
        baseURL = url
    }

    func get<T: Decodable>(_ path: String, authorized: Bool = false) async throws -> T {
        try await request(path, method: "GET", body: nil as EmptyBody?, authorized: authorized)
    }

    func post<Body: Encodable, T: Decodable>(
        _ path: String,
        body: Body,
        authorized: Bool = false
    ) async throws -> T {
        try await request(path, method: "POST", body: body, authorized: authorized)
    }

    /// POST with empty body; decodes JSON or accepts 204 No Content when `T` is unused via `postNoContent`.
    func postEmpty<T: Decodable>(_ path: String, authorized: Bool = true) async throws -> T {
        try await request(
            path,
            method: "POST",
            body: nil as EmptyBody?,
            authorized: authorized,
            allowEmptyBody: true
        )
    }

    func postNoContent(_ path: String, authorized: Bool = true) async throws {
        let _: EmptyResponse = try await request(
            path,
            method: "POST",
            body: nil as EmptyBody?,
            authorized: authorized,
            allowEmptyBody: true
        )
    }

    func put<Body: Encodable, T: Decodable>(
        _ path: String,
        body: Body,
        authorized: Bool = true
    ) async throws -> T {
        try await request(path, method: "PUT", body: body, authorized: authorized)
    }

    func patch<Body: Encodable, T: Decodable>(
        _ path: String,
        body: Body,
        authorized: Bool = true
    ) async throws -> T {
        try await request(path, method: "PATCH", body: body, authorized: authorized)
    }

    func delete(_ path: String, authorized: Bool = true) async throws {
        let _: EmptyResponse = try await request(
            path,
            method: "DELETE",
            body: nil as EmptyBody?,
            authorized: authorized,
            allowEmptyBody: true
        )
    }

    func deleteJSON<T: Decodable>(_ path: String, authorized: Bool = true) async throws -> T {
        try await request(
            path,
            method: "DELETE",
            body: nil as EmptyBody?,
            authorized: authorized,
            allowEmptyBody: false
        )
    }

    private struct EmptyBody: Encodable {}
    private struct EmptyResponse: Decodable {}

    private func request<Body: Encodable, T: Decodable>(
        _ path: String,
        method: String,
        body: Body?,
        authorized: Bool,
        allowEmptyBody: Bool = false,
        isRetryAfterRefresh: Bool = false
    ) async throws -> T {
        let url = try makeURL(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(body)
        }
        if authorized, let token = KeychainTokenStore.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ServiceError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw ServiceError.network("无效的服务器响应")
        }

        if http.statusCode == 401, authorized, !isRetryAfterRefresh {
            let refreshed = try await refreshTokensIfPossible()
            if refreshed {
                return try await self.request(
                    path,
                    method: method,
                    body: body,
                    authorized: authorized,
                    allowEmptyBody: allowEmptyBody,
                    isRetryAfterRefresh: true
                )
            }
            throw ServiceError.unauthorized
        }

        guard (200 ..< 300).contains(http.statusCode) else {
            let detail = String(data: data, encoding: .utf8) ?? ""
            if http.statusCode == 401 || http.statusCode == 403 {
                throw ServiceError.unauthorized
            }
            if http.statusCode == 404 {
                throw ServiceError.notFound(path)
            }
            throw ServiceError.httpStatus(http.statusCode, truncate(detail))
        }

        if allowEmptyBody, data.isEmpty, T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw ServiceError.decoding(error.localizedDescription)
        }
    }

    private func makeURL(_ path: String) throws -> URL {
        let trimmed = path.hasPrefix("/") ? path : "/\(path)"
        guard let url = URL(string: trimmed, relativeTo: baseURL)?.absoluteURL else {
            throw ServiceError.invalidState("无效 API 路径：\(path)")
        }
        return url
    }

    private func refreshTokensIfPossible() async throws -> Bool {
        guard !isRefreshing else { return false }
        guard let refresh = KeychainTokenStore.refreshToken else { return false }
        isRefreshing = true
        defer { isRefreshing = false }

        struct RefreshBody: Encodable { let refresh_token: String }
        struct TokenDTO: Decodable {
            let access_token: String
            let refresh_token: String
        }

        do {
            let tokens: TokenDTO = try await request(
                "/v1/auth/refresh",
                method: "POST",
                body: RefreshBody(refresh_token: refresh),
                authorized: false,
                isRetryAfterRefresh: true
            )
            KeychainTokenStore.save(accessToken: tokens.access_token, refreshToken: tokens.refresh_token)
            return true
        } catch {
            KeychainTokenStore.clear()
            return false
        }
    }

    private func truncate(_ text: String, limit: Int = 180) -> String {
        guard text.count > limit else { return text }
        return String(text.prefix(limit)) + "…"
    }
}
