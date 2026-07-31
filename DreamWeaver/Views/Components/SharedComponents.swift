import SwiftUI

struct GlassPanel: ViewModifier {
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(DreamTheme.panel)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(DreamTheme.divider, lineWidth: 1)
                    }
            }
    }
}

/// Scene chrome matching the mix disk surface opacity (no frosted material).
struct DiskMatchedChrome: ViewModifier {
    var cornerRadius: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(DreamTheme.chromeSurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(DreamTheme.chromeStroke, lineWidth: 1)
                    }
            }
    }
}

extension View {
    func dreamGlass(cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassPanel(cornerRadius: cornerRadius))
    }

    func dreamDiskChrome(cornerRadius: CGFloat = 24) -> some View {
        modifier(DiskMatchedChrome(cornerRadius: cornerRadius))
    }
}

struct SectionHeader: View {
    let title: String
    var trailing: AnyView? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(DreamTheme.moonWhite)
            Spacer()
            if let trailing {
                trailing
            }
        }
    }
}

struct EmptyStateView: View {
    let symbol: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: symbol)
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(DreamTheme.mistBlue)
                .accessibilityHidden(true)

            Text(message)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(DreamTheme.secondaryText)
                .multilineTextAlignment(.center)

            Button(action: action) {
                Text(actionTitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(DreamTheme.midnight)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(DreamTheme.moonWhite.opacity(0.92)))
            }
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

struct CapsuleChip: View {
    let title: String
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: selected ? .medium : .regular))
                .foregroundStyle(selected ? DreamTheme.midnight : DreamTheme.moonWhite.opacity(0.8))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    Capsule()
                        .fill(selected ? DreamTheme.moonWhite.opacity(0.92) : Color.white.opacity(0.08))
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Timer chip with silent left-to-right fill for countdown options.
struct TimerOptionChip: View {
    let option: TimerOption
    var selected: Bool
    /// Elapsed fraction 0...1. Only applied when selected countdown option.
    var progress: Double
    var action: () -> Void

    private var showFill: Bool {
        selected && option.showsCountdownFill
    }

    var body: some View {
        Button(action: action) {
            Text(option.rawValue)
                .font(.system(size: 13, weight: selected ? .medium : .regular))
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background {
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(baseFill)

                        if showFill {
                            GeometryReader { geo in
                                Capsule()
                                    .fill(DreamTheme.warmApricot.opacity(0.72))
                                    .frame(width: max(geo.size.width * progress, progress > 0 ? 4 : 0))
                                    .animation(.linear(duration: 0.25), value: progress)
                            }
                        }
                    }
                    .clipShape(Capsule())
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.rawValue)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityValue(showFill ? "定时进行中" : "")
    }

    private var baseFill: Color {
        if showFill {
            return Color.white.opacity(0.12)
        }
        return selected ? DreamTheme.moonWhite.opacity(0.92) : Color.white.opacity(0.08)
    }

    private var textColor: Color {
        if showFill {
            return DreamTheme.moonWhite
        }
        return selected ? DreamTheme.midnight : DreamTheme.moonWhite.opacity(0.8)
    }
}
