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
    /// Simulator default for remote mode.
    static let defaultRemoteBaseURL = URL(string: "http://127.0.0.1:8000")!

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

    static var remoteBaseURL: URL {
        if let override = UserDefaults.standard.string(forKey: "dw.apiBaseURL"),
           let url = URL(string: override), !override.isEmpty {
            return url
        }
        return defaultRemoteBaseURL
    }
}
