import AuthenticationServices
import CryptoKit
import SwiftUI

/// Profile account chrome: Sign in with Apple → `AppState.signInWithApple`,
/// sign-out → `signOutRemote`, session via `isRemoteAuthenticated`.
struct AppleSignInSection: View {
    @EnvironmentObject private var appState: AppState
    @State private var currentNonce: String?
    @State private var isBusy = false
    @State private var localError: String?

    private var isRemote: Bool {
        appState.contentBackendMode == .remote
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("账户")
                .font(DreamTypography.sectionTitle)
                .foregroundStyle(DreamTheme.moonWhite)

            VStack(alignment: .leading, spacing: 12) {
                statusRow

                if isRemote {
                    if appState.isRemoteAuthenticated {
                        Button {
                            Task { await signOut() }
                        } label: {
                            Text(isBusy ? "退出中…" : "退出登录")
                                .font(DreamTypography.callout)
                                .foregroundStyle(DreamTheme.moonWhite)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.white.opacity(0.10))
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(isBusy)
                        .accessibilityLabel("退出远程登录")
                    } else {
                        SignInWithAppleButton(.signIn) { request in
                            prepareRequest(request)
                        } onCompletion: { result in
                            handleAuthorization(result)
                        }
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .disabled(isBusy)
                        .accessibilityLabel("通过 Apple 登录")

                        // Simulator SIWA often hangs / times out before returning a token.
                        // Keep the verified demo path next to Apple for remote联调.
                        Button {
                            Task { await signInWithDevAccount() }
                        } label: {
                            Text(isBusy ? "登录中…" : "开发登录（dev:demo-user）")
                                .font(DreamTypography.callout)
                                .foregroundStyle(DreamTheme.moonWhite)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.white.opacity(0.10))
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(isBusy)
                        .accessibilityLabel("开发登录")

                        #if targetEnvironment(simulator)
                        Text("模拟器上系统 Apple 登录常会超时；联调请用开发登录。真机再验正式 Apple。")
                            .font(DreamTypography.caption)
                            .foregroundStyle(DreamTheme.tertiaryText)
                        #endif
                    }
                } else {
                    Text("切换到「远程 API」并重启后，可使用 Apple 登录同步收藏与设置。")
                        .font(DreamTypography.caption)
                        .foregroundStyle(DreamTheme.tertiaryText)
                }

                if let localError {
                    Text(localError)
                        .font(DreamTypography.caption)
                        .foregroundStyle(DreamTheme.warmApricot)
                } else if let message = appState.lastServiceMessage,
                          message.contains("登录") || message.contains("退出") {
                    Text(message)
                        .font(DreamTypography.caption)
                        .foregroundStyle(DreamTheme.secondaryText)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
        }
    }

    private var statusRow: some View {
        HStack(spacing: 10) {
            Image(systemName: statusSymbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(DreamTheme.mistBlue)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(statusTitle)
                    .font(DreamTypography.cardTitle)
                    .foregroundStyle(DreamTheme.moonWhite)
                Text(statusSubtitle)
                    .font(DreamTypography.caption)
                    .foregroundStyle(DreamTheme.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(statusTitle)，\(statusSubtitle)")
    }

    private var statusSymbol: String {
        if !isRemote { return "internaldrive" }
        return appState.isRemoteAuthenticated ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.questionmark"
    }

    private var statusTitle: String {
        if !isRemote { return "本地演示" }
        return appState.isRemoteAuthenticated ? "已登录" : "未登录"
    }

    private var statusSubtitle: String {
        if !isRemote {
            return "当前使用本地演示数据"
        }
        if appState.isRemoteAuthenticated {
            return "Apple 账户已连接 · \(appState.nickname)"
        }
        return "登录后可同步收藏、设置与云端混音"
    }

    private func prepareRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256Hex(nonce)
        localError = nil
    }

    private func handleAuthorization(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            localError = appleErrorMessage(error)
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8)
            else {
                localError = "无法读取 Apple identity token"
                return
            }
            let nonce = currentNonce
            let suggestedName: String? = {
                guard let full = credential.fullName else { return nil }
                let parts = [full.givenName, full.familyName].compactMap { $0 }
                let joined = parts.joined(separator: " ")
                return joined.isEmpty ? nil : joined
            }()
            Task { await completeSignIn(identityToken: identityToken, nonce: nonce, nickname: suggestedName) }
        }
    }

    private func appleErrorMessage(_ error: Error) -> String? {
        let ns = error as NSError
        if ns.domain == ASAuthorizationError.errorDomain {
            switch ns.code {
            case ASAuthorizationError.canceled.rawValue:
                return nil
            case ASAuthorizationError.unknown.rawValue:
                return "Apple 登录未响应（模拟器常见）。请用下方开发登录，或换真机重试。"
            case ASAuthorizationError.failed.rawValue:
                return "Apple 登录失败。请确认模拟器已登录 Apple ID，或改用开发登录。"
            case ASAuthorizationError.invalidResponse.rawValue:
                return "Apple 返回无效响应。请改用开发登录或真机重试。"
            case ASAuthorizationError.notHandled.rawValue:
                return "系统未处理该登录请求。请改用开发登录。"
            default:
                break
            }
        }
        let text = error.localizedDescription
        if text.localizedCaseInsensitiveContains("timeout")
            || text.contains("超时")
            || text.localizedCaseInsensitiveContains("timed out") {
            return "Apple 登录超时（多半是模拟器系统授权卡住）。联调请点「开发登录」。"
        }
        return text
    }

    @MainActor
    private func completeSignIn(identityToken: String, nonce: String?, nickname: String?) async {
        isBusy = true
        localError = nil
        defer { isBusy = false }
        await appState.signInWithApple(
            identityToken: identityToken,
            nickname: nickname ?? appState.nickname,
            nonce: nonce
        )
        if !appState.isRemoteAuthenticated {
            localError = appState.lastServiceMessage ?? "登录未完成"
        }
    }

    @MainActor
    private func signInWithDevAccount() async {
        isBusy = true
        localError = nil
        defer { isBusy = false }
        await appState.signInWithDevAccount()
        if !appState.isRemoteAuthenticated {
            localError = appState.lastServiceMessage ?? "开发登录未完成"
        }
    }

    @MainActor
    private func signOut() async {
        isBusy = true
        localError = nil
        defer { isBusy = false }
        await appState.signOutRemote()
    }

    // MARK: - Nonce

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        result.reserveCapacity(length)
        for _ in 0..<length {
            result.append(charset[Int.random(in: 0..<charset.count)])
        }
        return result
    }

    private static func sha256Hex(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
