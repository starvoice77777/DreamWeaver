import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var createHubEntryID = UUID()

    private var reduceMotion: Bool {
        appState.reduceMotion || systemReduceMotion
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch appState.selectedTab {
                case .now:
                    NowView()
                case .create:
                    CreateHubView()
                        // Every tab entry starts at the hub instead of restoring a
                        // previously presented blank-scene editor or creation flow.
                        .id(createHubEntryID)
                case .profile:
                    ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(appState.isTransitioningScene ? 0.2 : 1)
            .animation(.easeInOut(duration: reduceMotion ? 0.2 : 0.7), value: appState.isTransitioningScene)

            DreamTabBar(selected: $appState.selectedTab)
                .padding(.bottom, 6)
                .opacity(tabBarChromeVisible ? 1 : 0)
                .scaleEffect(tabBarChromeVisible ? 1 : 0.98)
                .allowsHitTesting(tabBarChromeVisible)
                .accessibilityHidden(!tabBarChromeVisible)
                .animation(DreamTheme.chromeVisibilityAnimation, value: tabBarChromeVisible)
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
                // Returning to「此刻」always brings chrome / tab bar back out.
                withAnimation(DreamTheme.chromeVisibilityAnimation) {
                    appState.revealControls()
                }
            } else if tab == .create {
                createHubEntryID = UUID()
            }
        }
    }

    /// Match Now chrome: hide with the mix disk on「此刻」; stay available on other tabs.
    private var tabBarChromeVisible: Bool {
        appState.selectedTab != .now || appState.controlsVisible
    }
}

struct DreamTabBar: View {
    @EnvironmentObject private var appState: AppState
    @Binding var selected: AppTab
    @State private var draggedTab: AppTab?
    @State private var dragProgress: CGFloat?
    @State private var isTrackingDrag = false
    @State private var barWidth: CGFloat = 0

    private let barHeight: CGFloat = 56
    private let barMaxWidth: CGFloat = 280

    private var displayedSelection: AppTab {
        draggedTab ?? selected
    }

    private var tabs: [AppTab] { AppTab.allCases }

    private var createIndex: CGFloat {
        CGFloat(tabs.firstIndex(of: .create) ?? 2)
    }

    /// Continuous 0…n-1 progress used by the lens and icon fills while dragging.
    private var selectionProgress: CGFloat {
        if let dragProgress {
            return dragProgress
        }
        return CGFloat(tabs.firstIndex(of: selected) ?? 0)
    }

    /// 0…1 proximity to the create slot — drives plus grow during continuous drag.
    private var createGrow: CGFloat {
        let distance = abs(selectionProgress - createIndex)
        return max(0, 1 - distance)
    }

    private var selectionDiameter: CGFloat {
        barHeight - 8 + 4 * createGrow
    }

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                let width = geometry.size.width
                Color.clear
                    .onAppear { barWidth = width }
                    .onChange(of: width) { _, newWidth in
                        barWidth = newWidth
                    }

                selectionLens(in: geometry.size)
            }

            HStack(spacing: 0) {
                ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                    tabButton(tab, index: index)
                }
            }
        }
        .frame(maxWidth: barMaxWidth)
        .frame(height: barHeight)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .dreamRefractiveLiquidGlassCapsule(
            accent: createGrow > 0.55
                ? DreamTheme.warmApricot
                : appState.currentScene.palette.accentColor,
            intensity: 0.84 + 0.10 * createGrow,
            interactive: true
        )
        .highPriorityGesture(tabDragGesture)
        .sensoryFeedback(.selection, trigger: displayedSelection.rawValue)
        .shadow(color: .black.opacity(0.18), radius: 16, y: 7)
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    private func selectionLens(in size: CGSize) -> some View {
        let count = CGFloat(max(tabs.count, 1))
        let segmentWidth = size.width / count
        let lensX = segmentWidth * (selectionProgress + 0.5)
        let diameter = min(selectionDiameter, size.height - 4)
        let fillOpacity = createGrow > 0.55
            ? 0.10 + 0.08 * createGrow
            : 0.09
        let fillColor = createGrow > 0.55
            ? DreamTheme.warmApricot.opacity(fillOpacity)
            : DreamTheme.moonWhite.opacity(fillOpacity)

        return Circle()
            .fill(fillColor)
            .frame(width: diameter, height: diameter)
            .dreamSpatialLiquidGlassCircle(
                accent: createGrow > 0.55
                    ? DreamTheme.warmApricot
                    : appState.currentScene.palette.accentColor,
                intensity: 0.92
            )
            .position(x: lensX, y: size.height / 2)
            .animation(lensAnimation, value: selectionProgress)
            .allowsHitTesting(false)
    }

    private var lensAnimation: Animation? {
        isTrackingDrag ? nil : .spring(response: 0.36, dampingFraction: 0.78)
    }

    @ViewBuilder
    private func tabButton(_ tab: AppTab, index: Int) -> some View {
        let isCommittedSelection = selected == tab
        let isCreate = tab.isElevatedCenter
        let fill = iconFillMetrics(for: index)

        if isCreate {
            Button {
                guard !isTrackingDrag else { return }
                select(tab)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(
                        DreamTheme.moonWhite.opacity(0.68 + 0.32 * createGrow)
                    )
                    .scaleEffect(1.0 + 0.22 * createGrow)
                    .animation(
                        isTrackingDrag
                            ? .interactiveSpring(response: 0.2, dampingFraction: 0.86)
                            : .spring(response: 0.34, dampingFraction: 0.70),
                        value: createGrow
                    )
                    .frame(width: 36, height: 36)
                    .frame(maxWidth: .infinity)
                    .frame(height: barHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(CreatePlusGrowButtonStyle(baseGrow: createGrow))
            .allowsHitTesting(!isTrackingDrag)
            .accessibilityLabel(tab.title)
            .accessibilityHint("创建或保存个人场景")
            .accessibilityAddTraits(isCommittedSelection ? .isSelected : [])
        } else {
            Button {
                guard !isTrackingDrag else { return }
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
                .scaleEffect(0.94 + fill.fraction * 0.18)
                .frame(width: 36, height: 36)
                .frame(maxWidth: .infinity)
                .frame(height: barHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .allowsHitTesting(!isTrackingDrag)
            .accessibilityLabel(tab.title)
            .accessibilityAddTraits(isCommittedSelection ? .isSelected : [])
        }
    }

    private var tabDragGesture: some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .local)
            .onChanged { value in
                if !isTrackingDrag {
                    // Lock into horizontal tracking once the drag clearly prefers X.
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    isTrackingDrag = true
                }

                let progress = progress(at: value.location.x)
                dragProgress = progress
                let tab = tab(at: progress)
                if draggedTab != tab {
                    draggedTab = tab
                }
            }
            .onEnded { value in
                defer {
                    isTrackingDrag = false
                }

                guard isTrackingDrag || abs(value.translation.width) >= abs(value.translation.height) else {
                    draggedTab = nil
                    dragProgress = nil
                    return
                }

                let finalProgress = dragProgress ?? progress(at: value.location.x)
                select(tab(at: finalProgress))
            }
    }

    private func progress(at x: CGFloat) -> CGFloat {
        guard barWidth > 0, !tabs.isEmpty else { return selectionProgress }
        let segmentWidth = barWidth / CGFloat(tabs.count)
        let rawProgress = (x / segmentWidth) - 0.5
        return min(max(rawProgress, 0), CGFloat(tabs.count - 1))
    }

    private func tab(at progress: CGFloat) -> AppTab {
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
        let iconWidth: CGFloat = 32
        guard barWidth > 0, !tabs.isEmpty else {
            let selectedIndex = tabs.firstIndex(of: selected) ?? 0
            return selectedIndex == index
                ? (iconWidth, 0, 1)
                : (0, 0, 0)
        }

        // Create uses proximity grow, not partial fill.
        if tabs[index].isElevatedCenter {
            return (0, 0, 0)
        }

        let segmentWidth = barWidth / CGFloat(tabs.count)
        let lensHalfWidth = selectionDiameter / 2
        let iconHalfWidth = iconWidth / 2
        let lensCenter = (selectionProgress - CGFloat(index)) * segmentWidth
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
    }
}

/// Extra press pop on top of continuous drag proximity grow.
private struct CreatePlusGrowButtonStyle: ButtonStyle {
    var baseGrow: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.12 : 1.0)
            .animation(
                .spring(response: 0.26, dampingFraction: 0.58),
                value: configuration.isPressed
            )
    }
}

#Preview {
    RootTabView()
        .environmentObject(AppState())
}
