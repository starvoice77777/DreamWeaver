import SwiftUI
import UniformTypeIdentifiers

struct SoundElementCard: View {
    let element: SoundElement
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: element.systemImage)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(IllustrationPalette.ink)
                    Spacer()
                    Circle()
                        .fill(color(for: element.colorToken))
                        .frame(width: 8, height: 8)
                }

                Text(element.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(IllustrationPalette.ink)
                    .lineLimit(1)

                Text(element.subtitle)
                    .font(.caption)
                    .foregroundStyle(IllustrationPalette.line)
                    .lineLimit(2)
            }
            .frame(width: 142, height: 92, alignment: .topLeading)
            .padding(13)
            .background(
                isSelected ? color(for: element.colorToken).opacity(0.22) : .white.opacity(0.74),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? color(for: element.colorToken).opacity(0.72) : IllustrationPalette.paleLine, lineWidth: isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(IllustrationPalette.ink.opacity(0.84))
        .onDrag { NSItemProvider(object: element.id as NSString) }
        .accessibilityLabel("声音：\(element.name)")
        .accessibilityHint("点击选择，再点击画布放入；也可以直接拖动到画布")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func color(for token: ColorToken) -> Color {
        switch token {
        case .night: IllustrationPalette.ink
        case .rain: IllustrationPalette.mist
        case .ember: IllustrationPalette.warm
        case .paper: Color(red: 0.76, green: 0.72, blue: 0.63)
        case .lavender: Color(red: 0.58, green: 0.58, blue: 0.72)
        case .gold: Color(red: 0.78, green: 0.64, blue: 0.30)
        }
    }
}
