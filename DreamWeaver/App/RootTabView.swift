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
    @State private var draggedTab: AppTab?
    @State private var dragProgress: CGFloat?
    @State private var barWidth: CGFloat = 0

    private var displayedSelection: AppTab {
        draggedTab ?? selected
    }

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                let count = CGFloat(AppTab.allCases.count)
                let spacing: CGFloat = 4
                let segmentWidth = (
                    geometry.size.width - spacing * max(count - 1, 0)
                ) / max(count, 1)
                let stride = segmentWidth + spacing

                selectionLens
                    .frame(width: segmentWidth - 2, height: geometry.size.height - 2)
                    .position(
                        x: segmentWidth / 2 + selectionProgress * stride,
                        y: geometry.size.height / 2
                    )
                    .animation(
                        .spring(response: 0.36, dampingFraction: 0.78),
                        value: selected
                    )
                    .allowsHitTesting(false)
            }

            HStack(spacing: 4) {
                ForEach(Array(AppTab.allCases.enumerated()), id: \.element.id) { index, tab in
                    tabButton(tab, index: index)
                }
            }
        }
        .frame(maxWidth: 352)
        .frame(height: 52)
        .padding(4)
        .frame(maxWidth: 360)
        .dreamRefractiveLiquidGlassCapsule(
            accent: appState.currentScene.palette.accentColor,
            intensity: 0.88,
            interactive: true
        )
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onAppear { barWidth = geometry.size.width }
                    .onChange(of: geometry.size.width) { _, width in
                        barWidth = width
                    }
            }
        }
        .highPriorityGesture(tabDragGesture)
        .sensoryFeedback(.selection, trigger: displayedSelection.rawValue)
        .shadow(color: .black.opacity(0.18), radius: 16, y: 7)
        .padding(.horizontal, 18)
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    private var selectionLens: some View {
        Capsule(style: .continuous)
            .fill(DreamTheme.moonWhite.opacity(0.09))
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.58),
                                Color.cyan.opacity(0.15),
                                Color.pink.opacity(0.11)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.85
                    )
                    .blendMode(.screen)
            }
    }

    private func tabButton(_ tab: AppTab, index: Int) -> some View {
        let isCommittedSelection = selected == tab
        let fill = iconFillMetrics(for: index)

        return Button {
            select(tab)
        } label: {
            ZStack {
                Image(systemName: tab.systemImageOutline)
                    .foregroundStyle(DreamTheme.mistBlue.opacity(0.38))

                Image(systemName: tab.systemImageFill)
                    .foregroundStyle(DreamTheme.moonWhite.opacity(0.96))
                    .mask {
                        Rectangle()
                            .frame(width: fill.width, height: 32)
                            .offset(x: fill.offset)
                    }
            }
            .font(.system(size: 22, weight: .medium))
            .frame(width: 32, height: 32)
            .scaleEffect(0.94 + fill.fraction * 0.18)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isCommittedSelection ? .isSelected : [])
    }

    private var tabDragGesture: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .local)
            .onChanged { value in
                guard abs(value.translation.width) >= abs(value.translation.height) else { return }
                let progress = progress(at: value.location.x)
                dragProgress = progress

                let tab = tab(at: progress)
                if draggedTab != tab {
                    draggedTab = tab
                }
            }
            .onEnded { value in
                guard abs(value.translation.width) >= abs(value.translation.height) else {
                    draggedTab = nil
                    dragProgress = nil
                    return
                }
                select(tab(at: dragProgress ?? progress(at: value.location.x)))
            }
    }

    private var selectionProgress: CGFloat {
        if let dragProgress {
            return dragProgress
        }
        return CGFloat(AppTab.allCases.firstIndex(of: selected) ?? 0)
    }

    private func progress(at x: CGFloat) -> CGFloat {
        let tabs = AppTab.allCases
        guard barWidth > 0, !tabs.isEmpty else { return selectionProgress }

        let outerInset: CGFloat = 4
        let spacing: CGFloat = 4
        let innerWidth = max(barWidth - outerInset * 2, 1)
        let segmentWidth = max(
            (innerWidth - spacing * CGFloat(tabs.count - 1)) / CGFloat(tabs.count),
            1
        )
        let stride = segmentWidth + spacing
        let rawProgress = (x - outerInset - segmentWidth / 2) / stride
        return min(max(rawProgress, 0), CGFloat(tabs.count - 1))
    }

    private func tab(at progress: CGFloat) -> AppTab {
        let tabs = AppTab.allCases
        guard !tabs.isEmpty else { return selected }
        let index = min(
            max(Int(progress.rounded()), 0),
            tabs.count - 1
        )
        return tabs[index]
    }

    private func iconFillMetrics(for index: Int) -> (
        width: CGFloat,
        offset: CGFloat,
        fraction: CGFloat
    ) {
        let tabs = AppTab.allCases
        let iconWidth: CGFloat = 32
        guard barWidth > 0, !tabs.isEmpty else {
            let selectedIndex = tabs.firstIndex(of: selected) ?? 0
            return selectedIndex == index
                ? (iconWidth, 0, 1)
                : (0, 0, 0)
        }

        let outerInset: CGFloat = 4
        let spacing: CGFloat = 4
        let innerWidth = max(barWidth - outerInset * 2, 1)
        let segmentWidth = max(
            (innerWidth - spacing * CGFloat(tabs.count - 1)) / CGFloat(tabs.count),
            1
        )
        let stride = segmentWidth + spacing
        let lensHalfWidth = max((segmentWidth - 2) / 2, 0)
        let iconHalfWidth = iconWidth / 2
        let lensCenter = (selectionProgress - CGFloat(index)) * stride
        let leftEdge = max(-iconHalfWidth, lensCenter - lensHalfWidth)
        let rightEdge = min(iconHalfWidth, lensCenter + lensHalfWidth)
        let coveredWidth = max(rightEdge - leftEdge, 0)
        let coveredCenter = (leftEdge + rightEdge) / 2

        return (
            width: coveredWidth,
            offset: coveredCenter,
            fraction: coveredWidth / iconWidth
        )
    }

    private func select(_ tab: AppTab) {
        withAnimation(.spring(response: 0.36, dampingFraction: 0.78)) {
            draggedTab = nil
            dragProgress = nil
            selected = tab
        }
        if tab == .now {
            appState.cancelReturnToNow()
        } else {
            appState.scheduleReturnToNowIfNeeded()
        }
    }
}

#Preview {
    RootTabView()
        .environmentObject(AppState())
}
