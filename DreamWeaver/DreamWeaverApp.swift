import SwiftUI

@main
struct DreamWeaverApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environment(\.font, DreamTypography.body)
        }
    }
}
