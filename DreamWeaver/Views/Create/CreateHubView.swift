import SwiftUI

/// First-class「创建」hub — personal scene authorship entry (roadmap §15.1).
struct CreateHubView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var draftStore = CreateDraftStore.shared
    @State private var isScenePickerPresented = false
    @State private var editorSeed: SpatialEditorSeed?
    @State private var isSpatialEditorPresented = false
    @State private var editorPresentationID = UUID()
    @State private var isOpeningRemoteDraft = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
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

                    if !draftStore.drafts.isEmpty {
                        draftSection
                    }

                    if appState.isRemoteAuthenticated, !remoteOnlySummaries.isEmpty {
                        remoteDraftSection
                    }

                    Spacer(minLength: 28)
                }
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
                    .environmentObject(appState)
            }
            .overlay {
                if isOpeningRemoteDraft {
                    ProgressView("打开云端草稿…")
                        .padding(20)
                        .dreamRefractiveLiquidGlassRounded(
                            cornerRadius: 18,
                            accent: DreamTheme.warmApricot,
                            intensity: 0.85
                        )
                }
            }
            .task {
                draftStore.reload()
                await appState.refreshPrivateSceneSummaries()
            }
        }
    }

    private var remoteOnlySummaries: [APIContentDTO.PrivateSceneSummary] {
        let localPrivateIds = Set(draftStore.drafts.compactMap(\.privateSceneId))
        return appState.privateSceneSummaries.filter { !localPrivateIds.contains($0.id) }
    }

    private var draftSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("我的草稿")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DreamTheme.moonWhite)
                .padding(.horizontal, 20)

            Text("保存在本机；登录远程后还会同步到云端私人场景。")
                .font(.system(size: 12))
                .foregroundStyle(DreamTheme.tertiaryText)
                .padding(.horizontal, 20)

            VStack(spacing: 10) {
                ForEach(draftStore.drafts) { draft in
                    draftRow(draft)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var remoteDraftSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("云端私人场景")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DreamTheme.moonWhite)
                .padding(.horizontal, 20)

            Text("其它设备或此前云端保存的草稿，点按可继续编辑。")
                .font(.system(size: 12))
                .foregroundStyle(DreamTheme.tertiaryText)
                .padding(.horizontal, 20)

            VStack(spacing: 10) {
                ForEach(remoteOnlySummaries) { summary in
                    remoteSummaryRow(summary)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func draftRow(_ draft: CreateSceneDraft) -> some View {
        Button {
            openEditor(with: .from(draft: draft))
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(DreamTheme.moonWhite)
                    .frame(width: 42, height: 42)
                    .background {
                        Circle().fill(Color.white.opacity(0.12))
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(draft.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(DreamTheme.moonWhite)
                        .lineLimit(1)
                    Text(draftMeta(draft))
                        .font(.system(size: 12))
                        .foregroundStyle(DreamTheme.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DreamTheme.tertiaryText)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dreamRefractiveLiquidGlassRounded(
                cornerRadius: 18,
                accent: DreamTheme.mistBlue,
                intensity: 0.72,
                interactive: true
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                draftStore.delete(id: draft.id)
            } label: {
                Label("删除本机草稿", systemImage: "trash")
            }
        }
        .accessibilityLabel("草稿 \(draft.name)")
    }

    private func remoteSummaryRow(_ summary: APIContentDTO.PrivateSceneSummary) -> some View {
        Button {
            Task { await openRemoteSummary(summary) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "icloud")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(DreamTheme.moonWhite)
                    .frame(width: 42, height: 42)
                    .background {
                        Circle().fill(Color.white.opacity(0.12))
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(DreamTheme.moonWhite)
                        .lineLimit(1)
                    Text(summary.has_saved_version ? "已发布 v\(summary.saved_version)" : "仅草稿")
                        .font(.system(size: 12))
                        .foregroundStyle(DreamTheme.secondaryText)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DreamTheme.tertiaryText)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dreamRefractiveLiquidGlassRounded(
                cornerRadius: 18,
                accent: DreamTheme.mistBlue,
                intensity: 0.72,
                interactive: true
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("云端场景 \(summary.name)")
    }

    private func draftMeta(_ draft: CreateSceneDraft) -> String {
        let trackCount = draft.soundSources.count
        let tracks = trackCount == 0 ? "尚无声源" : "\(trackCount) 条声源"
        let cloud = draft.privateSceneId == nil ? "仅本机" : "已同步云端"
        return "\(tracks) · \(cloud) · \(Self.relativeDate.localizedString(for: draft.updatedAt, relativeTo: Date()))"
    }

    private static let relativeDate: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    private func openEditor(with seed: SpatialEditorSeed) {
        editorSeed = seed
        editorPresentationID = UUID()
        isSpatialEditorPresented = true
    }

    private func openRemoteSummary(_ summary: APIContentDTO.PrivateSceneSummary) async {
        isOpeningRemoteDraft = true
        defer { isOpeningRemoteDraft = false }
        do {
            let detail = try await appState.fetchPrivateSceneDetail(id: summary.id)
            var seed = SpatialEditorSeed.from(privateDetail: detail)
            // Keep a stable local draft id if we already mirrored this private scene.
            if let local = draftStore.drafts.first(where: { $0.privateSceneId == summary.id }) {
                seed.draftID = local.id
            } else {
                seed.draftID = UUID()
            }
            openEditor(with: seed)
        } catch {
            appState.lastServiceMessage = error.localizedDescription
        }
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
