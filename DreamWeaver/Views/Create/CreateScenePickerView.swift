import SwiftUI

/// Scene chooser shown before opening the shared spatial editor from an existing draft.
struct CreateScenePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    let onSelect: (DreamScene) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    Text("选择一个已有场景作为底稿，编辑后另存为个人场景。")
                        .font(DreamTypography.callout)
                        .foregroundStyle(DreamTheme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 4)

                    ForEach(appState.scenes) { scene in
                        Button {
                            onSelect(scene)
                        } label: {
                            sceneRow(scene)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(DreamTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("选择场景")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(DreamTheme.warmApricot)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func sceneRow(_ scene: DreamScene) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(scene.palette.gradient)

                if let cover = SceneCoverArt.image(for: scene.visualStyle) {
                    Image(uiImage: cover)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(DreamTheme.moonWhite.opacity(0.88))
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 0.8)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(scene.name)
                    .font(DreamTypography.cardTitle)
                    .foregroundStyle(DreamTheme.moonWhite)
                    .lineLimit(1)

                Text(scene.subtitle)
                    .font(DreamTypography.caption)
                    .foregroundStyle(DreamTheme.secondaryText)
                    .lineLimit(1)

                Text("\(scene.soundSources.count) 个声源 · \(scene.category.rawValue)")
                    .font(DreamTypography.caption)
                    .foregroundStyle(DreamTheme.tertiaryText)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DreamTheme.tertiaryText)
        }
        .padding(14)
        .dreamRefractiveLiquidGlassRounded(
            cornerRadius: 18,
            accent: scene.palette.accentColor,
            intensity: 0.55,
            interactive: true
        )
        .accessibilityLabel(scene.name)
        .accessibilityHint("以该场景为底稿开始创建")
    }
}
