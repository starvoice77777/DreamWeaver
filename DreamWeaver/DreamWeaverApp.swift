import SwiftUI

@main
struct DreamWeaverApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environment(\.font, DreamTypography.body)
                .onChange(of: scenePhase) { _, phase in
                    guard phase != .active else { return }
                    Task { await appState.flushPendingSettingsSync() }
                }
        }
    }
}
