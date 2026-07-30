import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private var reduceMotion: Bool {
        appState.reduceMotion || systemReduceMotion
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch appState.selectedTab {
                case .now:
                    NowView()
                case .scenes:
                    SceneLibraryView()
                case .sounds:
                    SoundLibraryView()
                case .profile:
                    ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(appState.isTransitioningScene ? 0.2 : 1)
            .animation(.easeInOut(duration: reduceMotion ? 0.2 : 0.7), value: appState.isTransitioningScene)

            if shouldShowTabBar {
                DreamTabBar(selected: $appState.selectedTab)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 6)
            }

            // Soft curtain so tab / preview changes never flash harshly.
            Color.black
                .opacity(appState.isTransitioningScene ? 0.88 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(appState.isTransitioningScene)
                .animation(.easeInOut(duration: reduceMotion ? 0.2 : 0.75), value: appState.isTransitioningScene)
        }
        .background(DreamTheme.midnight.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.45), value: shouldShowTabBar)
        .fullScreenCover(item: $appState.previewScene) { scene in
            ScenePreviewView(scene: scene)
                .environmentObject(appState)
        }
    }

    private var shouldShowTabBar: Bool {
        if appState.isTransitioningScene { return false }
        if appState.selectedTab == .now {
            return appState.controlsVisible
        }
        return true
    }
}

struct DreamTabBar: View {
    @Binding var selected: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selected = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 18, weight: .regular))
                        Text(tab.title)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(selected == tab ? DreamTheme.moonWhite : DreamTheme.tertiaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(DreamTheme.divider, lineWidth: 1)
                }
        }
        .padding(.horizontal, 28)
        .shadow(color: .black.opacity(0.35), radius: 20, y: 8)
    }
}

#Preview {
    RootTabView()
        .environmentObject(AppState())
}
