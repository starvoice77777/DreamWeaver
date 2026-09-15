import SwiftUI

struct SoundTrayView: View {
    let elements: [SoundElement]
    let activeFilter: SoundCategory?
    let pendingElementID: String?
    let isExpanded: Bool
    let onToggleExpanded: () -> Void
    let onFilter: (SoundCategory?) -> Void
    let onSelect: (SoundElement) -> Void

    var body: some View {
        VStack(spacing: 12) {
            Capsule()
                .fill(.white.opacity(0.22))
                .frame(width: 34, height: 4)
                .padding(.top, 3)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("声音调色板")
                        .font(.headline.weight(.semibold))
                    Text(pendingElementID == nil ? "拖入画布，编织今晚的氛围" : "已选择一束声音，点击画布放入")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: onToggleExpanded) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                        .font(.caption.weight(.bold))
                        .frame(width: 30, height: 30)
                        .background(.white.opacity(0.09), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? "收起声音调色板" : "展开声音调色板")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    filterChip("全部", selected: activeFilter == nil) { onFilter(nil) }
                    ForEach(SoundCategory.allCases) { category in
                        filterChip(category.displayName, selected: activeFilter == category) {
                            onFilter(category)
                        }
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(elements) { element in
                        SoundElementCard(
                            element: element,
                            isSelected: pendingElementID == element.id,
                            onSelect: { onSelect(element) }
                        )
                    }
                }
                .padding(.bottom, 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .frame(maxHeight: isExpanded ? 350 : 245)
        .background(.white.opacity(0.90))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(IllustrationPalette.paleLine.opacity(0.72))
                .frame(height: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }

    private func filterChip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.caption.weight(.medium))
            .foregroundStyle(selected ? .white : IllustrationPalette.line)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(selected ? IllustrationPalette.ink : IllustrationPalette.paleLine.opacity(0.28), in: Capsule())
            .buttonStyle(.plain)
    }
}
