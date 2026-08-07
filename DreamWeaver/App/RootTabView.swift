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
            SharedTabAtmosphereBackground(
                scene: appState.currentScene,
                selectedTab: appState.selectedTab,
                isPlaying: appState.isPlaying,
                reduceMotion: reduceMotion,
                intensity: appState.animationIntensity
            )

            Group {
                switch appState.selectedTab {
                case .now:
                    NowView()
                case .create:
                    CreateHubView()
                        // Every tab entry starts with a fresh blank workspace.
                        .id(createHubEntryID)
                case .profile:
                    ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Root-tab changes only drive the shared backdrop and navigation
            // selection. Do not let that transaction leak into the newly
            // mounted page and animate its controls, layout, opacity or scale.
            .transaction(value: appState.selectedTab) { transaction in
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
            // Scene swipes may animate the shared backdrop, but the mounted
            // page must update atomically. Keeping this transaction local to
            // the foreground prevents palette changes from interpolating any
            // control position, scale or layout.
            .transaction(value: appState.currentSceneId) { transaction in
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
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
        .environment(\.sceneAdaptivePalette, appState.currentScene.palette)
        .onChange(of: appState.selectedTab) { _, tab in
            if tab == .now {
                // Returning to「此刻」restores chrome immediately. The tab
                // switch itself must not fade or scale foreground controls.
                var transaction = Transaction()
                transaction.animation = nil
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    appState.revealControls()
                }
            } else if tab == .create {
                createHubEntryID = UUID()
            }
        }
    }

}

struct DreamTabBar: View {
    private enum CollapsedDockSide {
        case leading
        case trailing
    }

    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Binding var selected: AppTab
    @State private var draggedTab: AppTab?
    @State private var dragProgress: CGFloat?
    @State private var isTrackingDrag = false
    @State private var barWidth: CGFloat = 0
    @State private var isCollapsed = false
    @State private var collapseTask: Task<Void, Never>?
    @State private var collapsedDockSide: CollapsedDockSide = .trailing
    @State private var collapsedDragTranslation: CGSize = .zero
    @State private var isDraggingCollapsedNavigation = false

    private let barHeight: CGFloat = 66
    private let barMaxWidth: CGFloat = 218
    private let barContentInset: CGFloat = 2
    private let idleCollapseDelay: Duration = .seconds(4)

    private var reduceMotion: Bool {
        appState.reduceMotion || systemReduceMotion
    }

    private var navigationWidth: CGFloat {
        isCollapsed ? barHeight : barMaxWidth
    }

    private var navigationChromeWidth: CGFloat {
        navigationWidth + barContentInset * 2
    }

    private var displayedSelection: AppTab {
        draggedTab ?? selected
    }

    private var tabs: [AppTab] { AppTab.allCases }

    /// Continuous 0…n-1 progress used by the lens and icon fills while dragging.
    private var selectionProgress: CGFloat {
        if let dragProgress {
            return dragProgress
        }
        return CGFloat(tabs.firstIndex(of: selected) ?? 0)
    }

    private var selectionDiameter: CGFloat {
        barHeight - 4
    }

    var body: some View {
        GeometryReader { proxy in
            navigationChrome
                .frame(width: navigationWidth, height: barHeight)
                .padding(.horizontal, barContentInset)
                .padding(.vertical, barContentInset)
                .position(
                    x: navigationCenterX(in: proxy.size.width),
                    y: navigationCenterY(in: proxy.size.height)
                )
                .highPriorityGesture(
                    collapsedDragGesture(in: proxy.size.width),
                    including: isCollapsed ? .all : .none
                )
        }
        .frame(height: barHeight + barContentInset * 2)
        .sensoryFeedback(.selection, trigger: displayedSelection.rawValue)
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 2)
        .onAppear {
            if appState.selectedTab == .now && !appState.controlsVisible {
                collapseNavigation()
            } else {
                scheduleCollapse()
            }
        }
        .onChange(of: appState.controlsVisible) { _, visible in
            guard appState.selectedTab == .now else { return }
            if visible {
                expandNavigation()
            } else {
                collapseNavigation()
            }
        }
        .onDisappear {
            collapseTask?.cancel()
        }
    }

    private var navigationChrome: some View {
        ZStack(alignment: .trailing) {
            expandedNavigationBar
                .frame(width: barMaxWidth, height: barHeight)
                .opacity(isCollapsed ? 0 : 1)
                .scaleEffect(
                    x: isCollapsed ? 0.72 : 1,
                    y: isCollapsed ? 0.90 : 1,
                    anchor: .trailing
                )
                .blur(radius: isCollapsed && !reduceMotion ? 1.2 : 0)
                .allowsHitTesting(!isCollapsed)
                .accessibilityHidden(isCollapsed)

            collapsedNavigationButton
                .frame(width: barHeight, height: barHeight)
                .opacity(isCollapsed ? 1 : 0)
                .scaleEffect(isCollapsed ? 1 : 0.76)
                .allowsHitTesting(isCollapsed)
                .accessibilityHidden(!isCollapsed)
        }
        .frame(width: navigationWidth, height: barHeight, alignment: .trailing)
        .background {
            Capsule(style: .continuous)
                .fill(DreamTheme.midnight.opacity(isCollapsed ? 0.97 : 0.94))
        }
        .clipShape(Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(
                    DreamTheme.componentAccent.opacity(isCollapsed ? 0.32 : 0.18),
                    lineWidth: isCollapsed ? 1 : 0.8
                )
        }
        .shadow(
            color: .black.opacity(isCollapsed ? 0.22 : 0.28),
            radius: isDraggingCollapsedNavigation ? 17 : (isCollapsed ? 10 : 14),
            y: isDraggingCollapsedNavigation ? 8 : (isCollapsed ? 4 : 6)
        )
        .scaleEffect(isDraggingCollapsedNavigation ? 1.045 : 1)
    }

    private func navigationCenterX(in availableWidth: CGFloat) -> CGFloat {
        guard isCollapsed else { return availableWidth / 2 }

        let halfWidth = navigationChromeWidth / 2
        let dockedCenter = collapsedDockSide == .leading
            ? halfWidth
            : availableWidth - halfWidth
        return min(
            max(dockedCenter + collapsedDragTranslation.width, halfWidth),
            availableWidth - halfWidth
        )
    }

    private func navigationCenterY(in availableHeight: CGFloat) -> CGFloat {
        guard isCollapsed else { return availableHeight / 2 }
        let lowerAreaOffset = min(
            max(collapsedDragTranslation.height, -180),
            12
        )
        return availableHeight / 2 + lowerAreaOffset
    }

    private func collapsedDragGesture(in availableWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .global)
            .onChanged { value in
                guard isCollapsed else { return }
                isDraggingCollapsedNavigation = true
                collapsedDragTranslation = value.translation
            }
            .onEnded { value in
                guard isCollapsed else { return }

                let halfWidth = navigationChromeWidth / 2
                let startingCenter = collapsedDockSide == .leading
                    ? halfWidth
                    : availableWidth - halfWidth
                let projectedCenter = startingCenter
                    + value.predictedEndTranslation.width
                let targetSide: CollapsedDockSide = projectedCenter < availableWidth / 2
                    ? .leading
                    : .trailing

                withAnimation(dockSnapAnimation) {
                    collapsedDockSide = targetSide
                    collapsedDragTranslation = .zero
                    isDraggingCollapsedNavigation = false
                }
            }
    }

    private var expandedNavigationBar: some View {
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
        .highPriorityGesture(tabDragGesture)
    }

    private var collapsedNavigationButton: some View {
        Button {
            expandNavigation()
        } label: {
            tabGlyph(selected, filled: true)
                .font(.system(size: DreamIconSize.primary, weight: .medium))
                .foregroundStyle(DreamTheme.moonWhite.opacity(0.98))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("展开导航")
        .accessibilityValue("当前页面：\(selected.title)")
        .accessibilityHint("展开后可切换页面")
    }

    private func selectionLens(in size: CGSize) -> some View {
        let count = CGFloat(max(tabs.count, 1))
        let segmentWidth = size.width / count
        let lensX = segmentWidth * (selectionProgress + 0.5)
        let diameter = min(selectionDiameter, size.height - 4)

        return Circle()
            .fill(DreamTheme.componentAccent.opacity(0.20))
            .frame(width: diameter, height: diameter)
            .overlay {
                Circle()
                    .strokeBorder(
                        DreamTheme.componentAccent.opacity(0.42),
                        lineWidth: 0.8
                    )
            }
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
        let fill = iconFillMetrics(for: index)

        Button {
            guard !isTrackingDrag else { return }
            select(tab)
        } label: {
            ZStack {
                tabGlyph(tab, filled: false)
                    .foregroundStyle(DreamTheme.moonWhite.opacity(0.60))

                tabGlyph(tab, filled: true)
                    .foregroundStyle(DreamTheme.moonWhite.opacity(0.98))
                    .mask {
                        Rectangle()
                            .frame(width: fill.width, height: 32)
                            .offset(x: fill.offset)
                    }
            }
            .font(.system(size: DreamIconSize.primary, weight: .medium))
            .frame(width: 36, height: 36)
            .frame(maxWidth: .infinity)
            .frame(height: barHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!isTrackingDrag)
        .accessibilityLabel(tab.title)
        .accessibilityHint(tab == .create ? "创建或保存个人场景" : "切换到\(tab.title)")
        .accessibilityAddTraits(isCommittedSelection ? .isSelected : [])
    }

    @ViewBuilder
    private func tabGlyph(_ tab: AppTab, filled: Bool) -> some View {
        if tab == .now {
            ZStack {
                ForEach(DreamWeaverMarkStroke.allCases) { stroke in
                    DreamWeaverMarkPath(stroke: stroke)
                        .stroke(
                            .primary,
                            style: StrokeStyle(
                                lineWidth: 2.1,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                }
            }
            .frame(width: 18, height: 30)
        } else {
            Image(systemName: filled ? tab.systemImageFill : tab.systemImageOutline)
        }
    }

    private var tabDragGesture: some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .local)
            .onChanged { value in
                if !isTrackingDrag {
                    // Lock into horizontal tracking once the drag clearly prefers X.
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    isTrackingDrag = true
                    collapseTask?.cancel()
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
        collapseTask?.cancel()

        // Commit the page outside the navigation spring. Otherwise the newly
        // inserted page inherits that transaction and briefly interpolates its
        // vertical layout on device while a horizontal tab swipe settles.
        selected = tab

        withAnimation(.spring(response: 0.36, dampingFraction: 0.78)) {
            isCollapsed = false
            draggedTab = nil
            dragProgress = nil
        }
        scheduleCollapse()
    }

    private func expandNavigation() {
        collapseTask?.cancel()
        withAnimation(expandAnimation) {
            isCollapsed = false
            collapsedDragTranslation = .zero
            isDraggingCollapsedNavigation = false
        }
        scheduleCollapse()
    }

    private func collapseNavigation() {
        collapseTask?.cancel()
        withAnimation(collapseAnimation) {
            isCollapsed = true
            draggedTab = nil
            dragProgress = nil
            isTrackingDrag = false
            collapsedDragTranslation = .zero
            isDraggingCollapsedNavigation = false
        }
    }

    private var expandAnimation: Animation {
        reduceMotion
            ? .easeInOut(duration: 0.18)
            : .spring(response: 0.56, dampingFraction: 0.84, blendDuration: 0.12)
    }

    private var collapseAnimation: Animation {
        reduceMotion
            ? .easeInOut(duration: 0.18)
            : .spring(response: 0.60, dampingFraction: 0.90, blendDuration: 0.14)
    }

    private var dockSnapAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.16)
            : .spring(response: 0.44, dampingFraction: 0.78, blendDuration: 0.08)
    }

    private func scheduleCollapse() {
        collapseTask?.cancel()
        guard !isCollapsed else { return }

        collapseTask = Task { @MainActor in
            do {
                try await Task.sleep(for: idleCollapseDelay)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            if isTrackingDrag {
                scheduleCollapse()
            } else {
                collapseNavigation()
            }
        }
    }
}

#Preview {
    RootTabView()
        .environmentObject(AppState())
}
