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
                    if phase == .active {
                        appState.resumeFromBackground()
                    } else {
                        appState.prepareNextLaunchScene()
                        Task { await appState.flushPendingSettingsSync() }
                    }
                }
        }
    }
}
