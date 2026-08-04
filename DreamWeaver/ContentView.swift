import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            // Keep「此刻」fully painted underneath so launch can crossfade into it
            // instead of dipping through black.
            RootTabView()

            if appState.showLaunch {
                LaunchDreamView()
                    .zIndex(1)
                    .transition(.identity)
                    .allowsHitTesting(true)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
