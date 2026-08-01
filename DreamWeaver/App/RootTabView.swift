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

            DreamTabBar(selected: $appState.selectedTab)
                .padding(.bottom, 6)
                .environmentObject(appState)

            // Soft curtain so tab / scene changes never flash harshly.
            Color.black
                .opacity(appState.isTransitioningScene ? 0.88 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(appState.isTransitioningScene)
                .animation(.easeInOut(duration: reduceMotion ? 0.2 : 0.75), value: appState.isTransitioningScene)
        }
        .background(DreamTheme.midnight.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onChange(of: appState.selectedTab) { _, tab in
            if tab == .now {
                appState.cancelReturnToNow()
            } else {
                appState.scheduleReturnToNowIfNeeded()
            }
        }
        // Drag only — a root TapGesture steals Menu/Picker presentation in Settings.
        .simultaneousGesture(
            DragGesture(minimumDistance: 12)
                .onChanged { _ in
                    appState.noteUserActivity()
                }
        )
    }
}

struct DreamTabBar: View {
    @EnvironmentObject private var appState: AppState
    @Binding var selected: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = selected == tab

        return Button {
            withAnimation(.easeInOut(duration: 0.28)) {
                selected = tab
            }
            if tab == .now {
                appState.cancelReturnToNow()
            } else {
                appState.scheduleReturnToNowIfNeeded()
            }
        } label: {
            Image(systemName: isSelected ? tab.systemImageFill : tab.systemImageOutline)
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(
                    isSelected
                        ? DreamTheme.mistBlue.opacity(0.95)
                        : DreamTheme.mistBlue.opacity(0.28)
                )
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    RootTabView()
        .environmentObject(AppState())
}
