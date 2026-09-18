import SwiftUI

struct AssistedFrameworkSelectionView: View {
    let selectedFramework: AssistedCreationFramework?
    let onBack: () -> Void
    let onSelect: (AssistedCreationFramework) -> Void
    let onContinue: (AssistedCreationFramework) -> Void

    var body: some View {
        VStack(spacing: 0) {
            AssistedFrameworkHeader(onBack: onBack)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    AssistedFrameworkIntroduction()

                    ForEach(AssistedCreationFramework.allCases) { framework in
                        AssistedFrameworkCard(
                            title: framework.title,
                            subtitle: framework.resultDescription,
                            systemImage: framework.systemImage,
                            isSelected: selectedFramework == framework,
                            action: { onSelect(framework) }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }

            AssistedFrameworkContinueBar(
                selectedFramework: selectedFramework,
                onContinue: onContinue
            )
        }
        .background(DreamTheme.midnight.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}

private struct AssistedFrameworkHeader: View {
    @Environment(\.sceneAdaptiveAccent) private var sceneAccent
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
            .accessibilityLabel("返回")

            Spacer()

            Text("选择声音关系")
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

private struct AssistedFrameworkIntroduction: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("想怎样听见这个空间？")
                .font(.title2.weight(.semibold))
                .foregroundStyle(DreamTheme.moonWhite)

            Text("先选择一种声音关系，系统再推荐与它匹配的内容。")
                .font(.subheadline)
                .foregroundStyle(DreamTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}

private struct AssistedFrameworkCard: View {
    @Environment(\.sceneAdaptiveAccent) private var sceneAccent
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title2.weight(.medium))
                    .foregroundStyle(isSelected ? sceneAccent : DreamTheme.secondaryText)
                    .frame(width: 48, height: 48)
                    .background(
                        sceneAccent.opacity(isSelected ? 0.16 : 0.07),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(DreamTheme.moonWhite)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(DreamTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 10)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isSelected ? sceneAccent : DreamTheme.tertiaryText)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(isSelected ? 0.09 : 0.05))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(sceneAccent.opacity(isSelected ? 0.65 : 0.16), lineWidth: 1)
                    }
            }
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("选择后可继续挑选声音")
    }
}

private struct AssistedFrameworkContinueBar: View {
    let selectedFramework: AssistedCreationFramework?
    let onContinue: (AssistedCreationFramework) -> Void

    var body: some View {
        Button {
            guard let selectedFramework else { return }
            onContinue(selectedFramework)
        } label: {
            Text("继续选择声音")
                .font(.headline)
                .foregroundStyle(selectedFramework == nil ? DreamTheme.tertiaryText : Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    selectedFramework == nil ? DreamTheme.divider : DreamTheme.moonWhite,
                    in: Capsule(style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .disabled(selectedFramework == nil)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 112)
        .background(.ultraThinMaterial)
    }
}

#Preview {
    AssistedFrameworkSelectionPreview()
}

private struct AssistedFrameworkSelectionPreview: View {
    @State private var selectedFramework: AssistedCreationFramework? = .boundaryGate

    var body: some View {
        AssistedFrameworkSelectionView(
            selectedFramework: selectedFramework,
            onBack: {},
            onSelect: { selectedFramework = $0 },
            onContinue: { _ in }
        )
    }
}
