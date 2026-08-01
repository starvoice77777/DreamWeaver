import Foundation

/// Auth endpoints for Sign in with Apple / `dev:<sub>` login. UI wiring comes later.
@MainActor
final class RemoteAuthService {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    struct AppleSignInBody: Encodable {
        let identity_token: String
        let nickname: String?
        let device_label: String?
        let nonce: String?
    }

    func signInWithApple(
        identityToken: String,
        nickname: String? = nil,
        deviceLabel: String? = nil,
        nonce: String? = nil
    ) async throws -> APIContentDTO.AuthTokens {
        let tokens: APIContentDTO.AuthTokens = try await client.post(
            "/v1/auth/apple",
            body: AppleSignInBody(
                identity_token: identityToken,
                nickname: nickname,
                device_label: deviceLabel,
                nonce: nonce
            ),
            authorized: false
        )
        KeychainTokenStore.save(accessToken: tokens.access_token, refreshToken: tokens.refresh_token)
        return tokens
    }

    /// Local smoke login without a real Apple JWT.
    func signInWithDevToken(sub: String, nickname: String? = nil) async throws -> APIContentDTO.AuthTokens {
        try await signInWithApple(identityToken: "dev:\(sub)", nickname: nickname, nonce: nil)
    }

    func logout() async throws {
        if KeychainTokenStore.accessToken != nil {
            try? await client.postNoContent("/v1/auth/logout", authorized: true)
        }
        KeychainTokenStore.clear()
    }

    var hasStoredSession: Bool {
        KeychainTokenStore.hasSession
    }
}
