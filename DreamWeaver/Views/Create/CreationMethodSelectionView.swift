import SwiftUI

struct CreationMethodSelectionView: View {
    let onAssistedCreation: () -> Void
    let onDetailedCreation: () -> Void
    let onOpenExisting: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                CreationMethodHero()

                CreationMethodCard(
                    title: "辅助创建",
                    subtitle: "通过声音关系和少量推荐，快速建立一个可以继续调整的空间。",
                    systemImage: "sparkles.rectangle.stack.fill",
                    badge: "推荐",
                    isPrimary: true,
                    action: onAssistedCreation
                )

                CreationMethodCard(
                    title: "深度创建",
                    subtitle: "直接进入完整控制台，自由调整声音位置、时间与变化。",
                    systemImage: "slider.horizontal.3",
                    badge: nil,
                    isPrimary: false,
                    action: onDetailedCreation
                )

                CreationExistingAction(action: onOpenExisting)
            }
            .padding(.horizontal, 20)
            .padding(.top, 54)
            .padding(.bottom, 120)
        }
        .background(DreamTheme.midnight.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}

private struct CreationMethodHero: View {
    @Environment(\.sceneAdaptiveAccent) private var sceneAccent

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "waveform.path.ecg.rectangle")
                .font(.system(size: DreamIconSize.emptyState, weight: .light))
                .foregroundStyle(sceneAccent)
                .frame(width: 72, height: 72)
                .background(sceneAccent.opacity(0.10), in: Circle())

            VStack(spacing: 6) {
                Text("创建你的声音空间")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(DreamTheme.moonWhite)

                Text("选择一种适合你的开始方式。之后随时可以进入精细调整。")
                    .font(.subheadline)
                    .foregroundStyle(DreamTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.bottom, 10)
    }
}

private struct CreationMethodCard: View {
    @Environment(\.sceneAdaptiveAccent) private var sceneAccent
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource
    let systemImage: String
    let badge: LocalizedStringResource?
    let isPrimary: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.title2.weight(.medium))
                    .foregroundStyle(isPrimary ? sceneAccent : DreamTheme.secondaryText)
                    .frame(width: 52, height: 52)
                    .background(
                        sceneAccent.opacity(isPrimary ? 0.16 : 0.06),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(DreamTheme.moonWhite)

                        if let badge {
                            Text(badge)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.black)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(sceneAccent, in: Capsule())
                        }
                    }

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(DreamTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(DreamTheme.tertiaryText)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(isPrimary ? 0.09 : 0.05))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(sceneAccent.opacity(isPrimary ? 0.52 : 0.14), lineWidth: 1)
                    }
            }
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint(isPrimary ? "进入辅助创建流程" : "直接打开精细调整控制台")
    }
}

private struct CreationExistingAction: View {
    @Environment(\.sceneAdaptiveAccent) private var sceneAccent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("继续已有场景或草稿", systemImage: "square.stack.3d.up.fill")
                .font(.callout.weight(.medium))
                .foregroundStyle(sceneAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .accessibilityHint("打开已有场景和草稿列表")
    }
}
