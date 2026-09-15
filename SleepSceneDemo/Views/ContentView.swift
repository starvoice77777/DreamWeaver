import SwiftUI

struct ContentView: View {
    @State private var composer = SceneComposer()
    @State private var pendingElementID: String?
    @State private var isTrayExpanded = false

    var body: some View {
        ZStack {
            Color(red: 0.94, green: 0.93, blue: 0.90)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    SceneStageView(
                        placements: composer.placements,
                        activeElements: composer.activeElements,
                        sceneTitle: composer.sceneTitle,
                        isPlaying: composer.isPlaying,
                        pendingElementID: pendingElementID,
                        onDropElementID: placeOnCanvas,
                        onCanvasTap: placePendingElement,
                        onRemove: removeElement
                    )
                    .padding(.horizontal, 14)
                    .padding(.top, 12)

                    SceneHeaderView(
                        title: composer.sceneTitle,
                        subtitle: composer.sceneSubtitle,
                        activeCount: composer.activeElementCount,
                        isPlaying: composer.isPlaying,
                        onTogglePlay: { composer.isPlaying.toggle() },
                        onExample: {
                            withAnimation(.easeInOut(duration: 0.8)) {
                                composer.loadExampleScene()
                                pendingElementID = nil
                            }
                        },
                        onClear: {
                            withAnimation(.easeInOut(duration: 0.8)) {
                                composer.clearScene()
                                pendingElementID = nil
                            }
                        }
                    )
                    .padding(.horizontal, 26)
                    .padding(.top, 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                SoundTrayView(
                    elements: composer.filteredElements,
                    activeFilter: composer.activeFilter,
                    pendingElementID: pendingElementID,
                    isExpanded: isTrayExpanded,
                    onToggleExpanded: { withAnimation(.snappy) { isTrayExpanded.toggle() } },
                    onFilter: { filter in
                        withAnimation(.snappy) { composer.activeFilter = filter }
                    },
                    onSelect: { element in
                        withAnimation(.snappy) { pendingElementID = element.id }
                    }
                )
            }
        }
        .preferredColorScheme(.light)
    }

    private func placeOnCanvas(elementID: String) {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.82)) {
            _ = composer.placeOnCanvas(elementID: elementID)
            pendingElementID = nil
        }
    }

    private func placePendingElement() {
        guard let pendingElementID else { return }
        placeOnCanvas(elementID: pendingElementID)
    }

    private func removeElement(_ slot: SceneSlotKind) {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) {
            composer.remove(from: slot)
        }
    }
}

#Preview("空白画布") { ContentView() }

#Preview("示例画布") {
    ExampleScenePreview()
}

@MainActor
private struct ExampleScenePreview: View {
    @State private var composer: SceneComposer

    init() {
        let value = SceneComposer()
        value.loadExampleScene()
        _composer = State(initialValue: value)
    }

    var body: some View {
        SceneStageView(
            placements: composer.placements,
            activeElements: composer.activeElements,
            sceneTitle: composer.sceneTitle,
            isPlaying: composer.isPlaying,
            pendingElementID: nil,
            onDropElementID: { _ in },
            onCanvasTap: {},
            onRemove: { _ in }
        )
        .padding()
        .background(Color.black)
    }
}
