import SwiftUI

struct AssistedMaterialCanvasView: View {
    @State private var draft: AssistedCreationDraft
    @State private var selectedZone: AssistedFrameworkZone
    @State private var generationState: AssistedSceneGenerationState = .idle
    @State private var generationTask: Task<Void, Never>?

    let onBack: () -> Void
    let onGenerate: (AssistedCreationDraft) async throws -> SpatialEditorSeed
    let onOpenEditor: (SpatialEditorSeed) -> Void

    init(
        draft: AssistedCreationDraft,
        onBack: @escaping () -> Void,
        onGenerate: @escaping (AssistedCreationDraft) async throws -> SpatialEditorSeed,
        onOpenEditor: @escaping (SpatialEditorSeed) -> Void
    ) {
        _draft = State(initialValue: draft)
        _selectedZone = State(initialValue: draft.framework.zones[0])
        self.onBack = onBack
        self.onGenerate = onGenerate
        self.onOpenEditor = onOpenEditor
    }

    var body: some View {
        VStack(spacing: 0) {
            AssistedMaterialHeader(
                frameworkTitle: draft.framework.title,
                onBack: onBack
            )

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    AssistedCanvasStage(
                        framework: draft.framework,
                        selections: draft.selections,
                        onRemove: removeMaterial
                    )

                    AssistedZonePicker(
                        zones: draft.framework.zones,
                        selectedZone: selectedZone,
                        onSelect: { selectedZone = $0 }
                    )

                    AssistedRecommendationSection(
                        materials: Self.recommendations[draft.framework] ?? [],
                        selectedMaterialIDs: Set(draft.selections.map(\.material.id)),
                        onToggle: toggleMaterial
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .disabled(generationState.isGenerating)
            }

            AssistedCanvasFooter(
                selectedCount: draft.selections.count,
                maximumCount: AssistedCreationDraft.maximumSoundCount,
                isGenerating: generationState.isGenerating,
                errorMessage: generationState.errorMessage,
                onContinue: beginGeneration
            )
        }
        .background(DreamTheme.midnight.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onDisappear {
            generationTask?.cancel()
            generationTask = nil
        }
    }

    private func toggleMaterial(_ material: SpatialEditorMaterial) {
        withAnimation(.easeInOut(duration: 0.2)) {
            generationState = .idle
            if draft.selections.contains(where: { $0.material.id == material.id }) {
                draft.remove(materialID: material.id)
            } else {
                _ = draft.add(material, to: selectedZone)
            }
        }
    }

    private func removeMaterial(_ materialID: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            generationState = .idle
            draft.remove(materialID: materialID)
        }
    }

    private func beginGeneration() {
        generationTask?.cancel()
        let snapshot = draft
        generationState = .generating
        generationTask = Task {
            do {
                let seed = try await onGenerate(snapshot)
                try Task.checkCancellation()
                generationState = .idle
                onOpenEditor(seed)
            } catch is CancellationError {
                generationState = .idle
            } catch {
                generationState = .failed(error.localizedDescription)
            }
            generationTask = nil
        }
    }

    private static let recommendations: [AssistedCreationFramework: [SpatialEditorMaterial]] = {
        let ids: [AssistedCreationFramework: [String]] = [
            .boundaryGate: ["rain", "wind", "bamboo"],
            .enclosureControl: ["rain", "bamboo", "stream"],
            .depthReveal: ["wind", "stream", "rain"],
            .focusSelector: ["rain", "bamboo", "towel"],
            .nearfieldWidth: ["stream", "towel", "bamboo"]
        ]
        return ids.mapValues { materialIDs in
            materialIDs.compactMap { materialID in
                SpatialEditorMaterial.catalog.first { $0.id == materialID }
            }
        }
    }()
}

private struct AssistedMaterialHeader: View {
    @Environment(\.sceneAdaptiveAccent) private var sceneAccent
    let frameworkTitle: LocalizedStringResource
    let onBack: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(sceneAccent)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("返回声音关系")

            Spacer()

            Text(frameworkTitle)
                .font(.headline)
                .foregroundStyle(DreamTheme.moonWhite)

            Spacer()

            Color.clear.frame(width: 44, height: 44)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }
}

private struct AssistedCanvasStage: View {
    let framework: AssistedCreationFramework
    let selections: [AssistedSoundSelection]
    let onRemove: (String) -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AssistedCanvasBackdrop(framework: framework)

                if framework != .boundaryGate {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title)
                        .foregroundStyle(DreamTheme.moonWhite)
                        .accessibilityLabel("聆听位置")
                }

                ForEach(selections) { selection in
                    AssistedSoundNode(
                        name: selection.material.name,
                        iconName: selection.material.iconName,
                        color: selection.material.themeColor,
                        onRemove: { onRemove(selection.material.id) }
                    )
                    .position(
                        x: proxy.size.width / 2 + selection.zone.editorPosition.x * proxy.size.width * 0.38,
                        y: proxy.size.height / 2 + selection.zone.editorPosition.y * proxy.size.height * 0.38
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .frame(height: 280)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("声音空间草图")
    }
}

private struct AssistedSoundNode: View {
    let name: String
    let iconName: String
    let color: Color
    let onRemove: () -> Void

    var body: some View {
        Button(action: onRemove) {
            VStack(spacing: 3) {
                Image(systemName: iconName)
                    .font(.body.weight(.semibold))
                Text(name)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .foregroundStyle(DreamTheme.moonWhite)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(color.opacity(0.34), in: Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("移除\(name)")
    }
}

private struct AssistedZonePicker: View {
    let zones: [AssistedFrameworkZone]
    let selectedZone: AssistedFrameworkZone
    let onSelect: (AssistedFrameworkZone) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("声音出现在哪里")
                .font(.headline)
                .foregroundStyle(DreamTheme.moonWhite)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(zones) { zone in
                        Button {
                            onSelect(zone)
                        } label: {
                            Text(zone.title)
                                .font(.callout.weight(.medium))
                                .foregroundStyle(selectedZone == zone ? Color.black : DreamTheme.moonWhite)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(
                                    selectedZone == zone ? DreamTheme.moonWhite : DreamTheme.panel,
                                    in: Capsule(style: .continuous)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selectedZone == zone ? .isSelected : [])
                    }
                }
            }
        }
    }
}

private struct AssistedRecommendationSection: View {
    let materials: [SpatialEditorMaterial]
    let selectedMaterialIDs: Set<String>
    let onToggle: (SpatialEditorMaterial) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("为你推荐")
                .font(.headline)
                .foregroundStyle(DreamTheme.moonWhite)

            HStack(spacing: 10) {
                ForEach(materials) { material in
                    AssistedRecommendationCard(
                        name: material.name,
                        iconName: material.iconName,
                        color: material.themeColor,
                        isSelected: selectedMaterialIDs.contains(material.id),
                        action: { onToggle(material) }
                    )
                }
            }
        }
    }
}

private struct AssistedRecommendationCard: View {
    let name: String
    let iconName: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(isSelected ? color : DreamTheme.secondaryText)
                Text(name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DreamTheme.moonWhite)
                    .lineLimit(1)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                    .font(.caption)
                    .foregroundStyle(isSelected ? color : DreamTheme.tertiaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(DreamTheme.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct AssistedCanvasFooter: View {
    let selectedCount: Int
    let maximumCount: Int
    let isGenerating: Bool
    let errorMessage: String?
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.88))
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("生成失败：\(errorMessage)")
            }

            Text("已选择 \(selectedCount) / \(maximumCount)")
                .font(.caption)
                .foregroundStyle(DreamTheme.secondaryText)

            Button(action: onContinue) {
                HStack(spacing: 8) {
                    if isGenerating {
                        ProgressView()
                            .tint(.black)
                    }
                    Text(buttonTitle)
                        .font(.headline)
                }
                    .foregroundStyle(isDisabled ? DreamTheme.tertiaryText : Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        isDisabled ? DreamTheme.divider : DreamTheme.moonWhite,
                        in: Capsule(style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 112)
        .background(.ultraThinMaterial)
    }

    private var isDisabled: Bool {
        selectedCount == 0 || isGenerating
    }

    private var buttonTitle: LocalizedStringResource {
        if isGenerating {
            return "正在生成场景…"
        }
        if errorMessage != nil {
            return "重新生成场景"
        }
        return "直接生成场景"
    }
}

private enum AssistedSceneGenerationState: Equatable {
    case idle
    case generating
    case failed(String)

    var isGenerating: Bool {
        self == .generating
    }

    var errorMessage: String? {
        guard case .failed(let message) = self else { return nil }
        return message
    }
}

private extension AssistedFrameworkZone {
    var title: LocalizedStringResource {
        switch self {
        case .outside: "窗外"
        case .inside: "室内"
        case .base: "安稳底层"
        case .surround: "包裹四周"
        case .detail: "近处细节"
        case .far: "远景"
        case .mid: "中景"
        case .near: "近景"
        case .objectA: "对象一"
        case .objectB: "对象二"
        case .objectC: "对象三"
        case .background: "背景"
        case .leftNear: "左侧近场"
        case .rightNear: "右侧近场"
        case .frontCompanion: "前方陪伴"
        }
    }
}
