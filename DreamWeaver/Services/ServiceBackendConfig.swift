import Foundation

/// Local mock vs remote FastAPI content backend.
enum ServiceBackendMode: String, CaseIterable, Identifiable {
    case local
    case remote

    var id: String { rawValue }

    var title: String {
        switch self {
        case .local: return "本地演示"
        case .remote: return "远程 API"
        }
    }
}

enum ServiceBackendConfig {
    static let defaultsKey = "dw.contentBackend"
    static let apiBaseURLKey = "dw.apiBaseURL"

    /// Simulator talks to the Mac loopback; device uses the LAN IP of the API host.
    static var defaultRemoteBaseURL: URL {
        #if targetEnvironment(simulator)
        URL(string: "http://127.0.0.1:8000")!
        #else
        // Current联调 LAN; override anytime via Settings → dw.apiBaseURL.
        URL(string: "http://192.168.120.62:8000")!
        #endif
    }

    static var mode: ServiceBackendMode {
        get {
            guard let raw = UserDefaults.standard.string(forKey: defaultsKey),
                  let mode = ServiceBackendMode(rawValue: raw) else {
                return .local
            }
            return mode
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey)
        }
    }

    static var usesRemoteAPI: Bool { mode == .remote }

    /// Persisted override for `dw.apiBaseURL`. Empty means use `defaultRemoteBaseURL`.
    static var apiBaseURLString: String {
        get {
            UserDefaults.standard.string(forKey: apiBaseURLKey) ?? ""
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                UserDefaults.standard.removeObject(forKey: apiBaseURLKey)
            } else {
                UserDefaults.standard.set(trimmed, forKey: apiBaseURLKey)
            }
        }
    }

    static var remoteBaseURL: URL {
        let override = apiBaseURLString
        if !override.isEmpty, let url = URL(string: override) {
            return url
        }
        return defaultRemoteBaseURL
    }
}
