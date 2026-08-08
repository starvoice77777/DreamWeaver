import SwiftUI

/// Chooses an existing scene or draft as the starting point for the root editor.
struct CreateScenePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @Environment(\.sceneAdaptiveAccent) private var sceneAccent

    let drafts: [CreateSceneDraft]
    let remoteDrafts: [APIContentDTO.PrivateSceneSummary]
    let onSelectScene: (DreamScene) -> Void
    let onSelectDraft: (CreateSceneDraft) -> Void
    let onSelectRemoteDraft: (APIContentDTO.PrivateSceneSummary) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if !drafts.isEmpty {
                        sectionTitle("我的草稿")
                        ForEach(drafts) { draft in
                            Button {
                                onSelectDraft(draft)
                            } label: {
                                draftRow(draft)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !remoteDrafts.isEmpty {
                        sectionTitle("云端草稿")
                        ForEach(remoteDrafts) { summary in
                            Button {
                                onSelectRemoteDraft(summary)
                            } label: {
                                remoteDraftRow(summary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    sectionTitle("已有场景")
                    ForEach(appState.scenes) { scene in
                        Button {
                            onSelectScene(scene)
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
            .background(DreamModalBackdrop())
            .navigationTitle("选择创建起点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    DreamModalCloseButton { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(DreamTypography.sectionTitle)
            .foregroundStyle(sceneAccent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
    }

    private func draftRow(_ draft: CreateSceneDraft) -> some View {
        sourceRow(
            title: draft.name,
            subtitle: "本机草稿 · \(draft.sourceGroupCount) 个声源",
            symbol: "doc.text.fill",
            accent: sceneAccent
        )
        .accessibilityHint("继续编辑此草稿")
    }

    private func remoteDraftRow(_ summary: APIContentDTO.PrivateSceneSummary) -> some View {
        sourceRow(
            title: summary.name,
            subtitle: summary.has_saved_version ? "云端草稿 · 已发布 v\(summary.saved_version)" : "云端草稿",
            symbol: "icloud.fill",
            accent: sceneAccent
        )
        .accessibilityHint("打开云端草稿")
    }

    private func sourceRow(
        title: String,
        subtitle: String,
        symbol: String,
        accent: Color
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: DreamIconSize.secondary, weight: .medium))
                .foregroundStyle(DreamTheme.moonWhite)
                .frame(width: 56, height: 56)
                .background(accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(DreamTypography.cardTitle)
                    .foregroundStyle(DreamTheme.moonWhite)
                    .lineLimit(1)
                Text(subtitle)
                    .font(DreamTypography.caption)
                    .foregroundStyle(DreamTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: DreamIconSize.content, weight: .semibold))
                .foregroundStyle(DreamTheme.tertiaryText)
        }
        .padding(14)
        .dreamRefractiveLiquidGlassRounded(
            cornerRadius: 18,
            accent: accent,
            intensity: 0.55,
            interactive: true
        )
        .accessibilityLabel(title)
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
                        .font(.system(size: DreamIconSize.secondary, weight: .medium))
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
                .font(.system(size: DreamIconSize.content, weight: .semibold))
                .foregroundStyle(DreamTheme.tertiaryText)
        }
        .padding(14)
        .dreamRefractiveLiquidGlassRounded(
            cornerRadius: 18,
            accent: DreamTheme.componentAccent,
            intensity: 0.55,
            interactive: true
        )
        .accessibilityLabel(scene.name)
        .accessibilityHint("以该场景为底稿开始创建")
    }
}
