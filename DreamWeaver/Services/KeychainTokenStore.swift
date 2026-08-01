import Foundation
import Security

/// Stores access / refresh tokens in Keychain (not UserDefaults).
enum KeychainTokenStore {
    private static let service = "zhimeng.DreamWeaver.auth"
    private static let accessAccount = "access_token"
    private static let refreshAccount = "refresh_token"

    static var accessToken: String? {
        get { read(account: accessAccount) }
        set { write(account: accessAccount, value: newValue) }
    }

    static var refreshToken: String? {
        get { read(account: refreshAccount) }
        set { write(account: refreshAccount, value: newValue) }
    }

    static var hasSession: Bool {
        accessToken != nil && refreshToken != nil
    }

    static func save(accessToken: String, refreshToken: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }

    static func clear() {
        accessToken = nil
        refreshToken = nil
    }

    private static func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func write(account: String, value: String?) {
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        guard let value, let data = value.data(using: .utf8) else { return }

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }
}
