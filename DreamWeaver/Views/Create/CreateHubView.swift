import SwiftUI

/// First-class「创建」hub — personal scene authorship entry (roadmap §15.1).
struct CreateHubView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isScenePickerPresented = false
    @State private var editorSeed: SpatialEditorSeed?
    @State private var isSpatialEditorPresented = false
    @State private var editorPresentationID = UUID()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeader(title: "创建")
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                Text("把声音、画面与陪伴收成你自己的梦境。")
                    .font(.system(size: 15))
                    .foregroundStyle(DreamTheme.secondaryText)
                    .padding(.horizontal, 20)

                VStack(spacing: 14) {
                    createActionCard(
                        title: "从空白开始",
                        subtitle: "选择画面气质、放入声音，再保存为个人场景",
                        symbol: "sparkles"
                    ) {
                        openEditor(with: .blank)
                    }

                    createActionCard(
                        title: "从已有场景创建",
                        subtitle: "挑选一个已有场景作为底稿，改完后另存为个人场景",
                        symbol: "slider.horizontal.3"
                    ) {
                        isScenePickerPresented = true
                    }
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(DreamTheme.backgroundGradient.ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(isPresented: $isScenePickerPresented) {
                CreateScenePickerView { scene in
                    isScenePickerPresented = false
                    // Allow the picker sheet to dismiss before presenting the editor.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        openEditor(with: .from(scene: scene))
                    }
                }
                .environmentObject(appState)
            }
            .fullScreenCover(isPresented: $isSpatialEditorPresented) {
                SpatialEditorView(seed: editorSeed ?? .blank)
                    .id(editorPresentationID)
            }
        }
    }

    private func openEditor(with seed: SpatialEditorSeed) {
        editorSeed = seed
        editorPresentationID = UUID()
        isSpatialEditorPresented = true
    }

    private func createActionCard(
        title: String,
        subtitle: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(DreamTheme.moonWhite)
                    .frame(width: 48, height: 48)
                    .background {
                        Circle().fill(Color.white.opacity(0.12))
                    }

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(DreamTheme.moonWhite)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(DreamTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DreamTheme.tertiaryText)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dreamRefractiveLiquidGlassRounded(
                cornerRadius: 22,
                accent: DreamTheme.warmApricot,
                intensity: 0.8,
                interactive: true
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
    }
}

#Preview {
    CreateHubView()
        .environmentObject(AppState())
}
