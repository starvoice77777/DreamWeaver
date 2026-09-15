import SwiftUI

struct SceneHeaderView: View {
    let title: String
    let subtitle: String
    let activeCount: Int
    let isPlaying: Bool
    let onTogglePlay: () -> Void
    let onExample: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(IllustrationPalette.ink)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(IllustrationPalette.line)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text("\(activeCount)/6")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(IllustrationPalette.ink.opacity(0.72))

            Button(action: onTogglePlay) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.caption.weight(.bold))
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.72), in: Circle())
            }
            .foregroundStyle(IllustrationPalette.ink)
            .accessibilityLabel(isPlaying ? "暂停场景" : "播放场景")

            Menu {
                Button("加载示例场景", systemImage: "wand.and.stars", action: onExample)
                Button("清空画布", systemImage: "trash", role: .destructive, action: onClear)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.headline.weight(.bold))
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.72), in: Circle())
            }
            .foregroundStyle(IllustrationPalette.ink)
            .accessibilityLabel("更多场景操作")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(IllustrationPalette.paleLine, lineWidth: 1)
        }
    }
}
