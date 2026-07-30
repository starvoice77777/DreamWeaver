import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            RootTabView()
                .opacity(appState.showLaunch ? 0 : 1)

            if appState.showLaunch {
                LaunchDreamView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.8), value: appState.showLaunch)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
