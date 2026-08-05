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

/// Clear, luminous “liquid glass” for mix nodes / chrome controls.
/// Fuller material body (not thinner) with brighter specular highlights.
struct LiquidGlassShape<S: InsettableShape>: View {
    var shape: S
    /// Approximate catch-light radius; circles use ~half the button size.
    var highlightRadius: CGFloat = 28

    var body: some View {
        ZStack {
            shape
                .fill(.thinMaterial)
                .opacity(0.88)

            shape
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.42),
                            Color.white.opacity(0.10),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            shape
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.35),
                            Color.white.opacity(0.0)
                        ],
                        center: UnitPoint(x: 0.32, y: 0.28),
                        startRadius: 0,
                        endRadius: highlightRadius
                    )
                )
                .blendMode(.screen)

            shape
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.78),
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.42)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.15
                )
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.10), radius: 7, y: 2)
    }
}

typealias LiquidGlassCircle = LiquidGlassShape<Circle>

/// Native iOS 26 refractive glass for draggable spatial-mix nodes.
///
/// Shu Ding's web implementation concentrates displacement at the edge of a
/// clear lens and adds a subtle chromatic fringe. SwiftUI's native clear glass
/// provides the backdrop refraction; the overlays below retain that rim detail.
struct SpatialLiquidGlassCircle: ViewModifier {
    var accent: Color
    var intensity: Double

    func body(content: Content) -> some View {
        let strength = max(0, min(1, intensity))

        content
            .background {
                Circle()
                    .fill(accent.opacity(0.025 + strength * 0.035))
            }
            .glassEffect(.clear.interactive(), in: Circle())
            .overlay {
                Circle()
                    .strokeBorder(
                        AngularGradient(
                            colors: [
                                Color.cyan.opacity(0.16 + strength * 0.08),
                                Color.white.opacity(0.64),
                                Color.pink.opacity(0.12 + strength * 0.07),
                                Color.white.opacity(0.24),
                                Color.cyan.opacity(0.16 + strength * 0.08)
                            ],
                            center: .center
                        ),
                        lineWidth: 0.85
                    )
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            }
            .overlay {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.22 + strength * 0.10),
                                Color.clear
                            ],
                            center: UnitPoint(x: 0.28, y: 0.22),
                            startRadius: 0,
                            endRadius: 24
                        )
                    )
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            }
    }
}

/// Noninteractive refractive surface for a grouped control such as a popup.
/// Keeping one glass sample for the whole capsule avoids nested-glass artifacts.
struct RefractiveLiquidGlassCapsule: ViewModifier {
    var accent: Color
    var intensity: Double
    var interactive: Bool

    func body(content: Content) -> some View {
        let strength = max(0, min(1, intensity))

        Group {
            if interactive {
                content
                    .background {
                        Capsule(style: .continuous)
                            .fill(accent.opacity(0.025 + strength * 0.035))
                    }
                    .glassEffect(.clear.interactive(), in: Capsule(style: .continuous))
            } else {
                content
                    .background {
                        Capsule(style: .continuous)
                            .fill(accent.opacity(0.025 + strength * 0.035))
                    }
                    .glassEffect(.clear, in: Capsule(style: .continuous))
            }
        }
        .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(
                        AngularGradient(
                            colors: [
                                Color.cyan.opacity(0.13 + strength * 0.07),
                                Color.white.opacity(0.58),
                                Color.pink.opacity(0.10 + strength * 0.06),
                                Color.white.opacity(0.20),
                                Color.cyan.opacity(0.13 + strength * 0.07)
                            ],
                            center: .center
                        ),
                        lineWidth: 0.85
                    )
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            }
            .overlay {
                Capsule(style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.18 + strength * 0.08),
                                Color.clear
                            ],
                            center: UnitPoint(x: 0.26, y: 0.10),
                            startRadius: 0,
                            endRadius: 64
                        )
                    )
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            }
    }
}

/// Rounded-rect refractive glass for library cards / wider chrome buttons.
/// Edge-weighted chromatic fringe follows Shu Ding's liquid-glass rim emphasis.
struct RefractiveLiquidGlassRounded: ViewModifier {
    var cornerRadius: CGFloat
    var accent: Color
    var intensity: Double
    var interactive: Bool

    func body(content: Content) -> some View {
        let strength = max(0, min(1, intensity))
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        Group {
            if interactive {
                content
                    .background {
                        shape.fill(accent.opacity(0.025 + strength * 0.035))
                    }
                    .glassEffect(.clear.interactive(), in: shape)
            } else {
                content
                    .background {
                        shape.fill(accent.opacity(0.025 + strength * 0.035))
                    }
                    .glassEffect(.clear, in: shape)
            }
        }
        .overlay {
            shape
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            Color.cyan.opacity(0.12 + strength * 0.07),
                            Color.white.opacity(0.55),
                            Color.pink.opacity(0.10 + strength * 0.06),
                            Color.white.opacity(0.18),
                            Color.cyan.opacity(0.12 + strength * 0.07)
                        ],
                        center: .center
                    ),
                    lineWidth: 0.9
                )
                .blendMode(.screen)
                .allowsHitTesting(false)
        }
        .overlay {
            shape
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.16 + strength * 0.08),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.22, y: 0.12),
                        startRadius: 0,
                        endRadius: max(cornerRadius * 2.4, 72)
                    )
                )
                .blendMode(.screen)
                .allowsHitTesting(false)
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

    func dreamLiquidGlassCircle() -> some View {
        background { LiquidGlassShape(shape: Circle()) }
    }

    func dreamLiquidGlassCapsule() -> some View {
        background {
            LiquidGlassShape(
                shape: Capsule(style: .continuous),
                highlightRadius: 48
            )
        }
    }

    func dreamSpatialLiquidGlassCircle(
        accent: Color = DreamTheme.mistBlue,
        intensity: Double = 0.75
    ) -> some View {
        modifier(
            SpatialLiquidGlassCircle(
                accent: accent,
                intensity: intensity
            )
        )
    }

    func dreamRefractiveLiquidGlassCapsule(
        accent: Color = DreamTheme.mistBlue,
        intensity: Double = 0.75,
        interactive: Bool = false
    ) -> some View {
        modifier(
            RefractiveLiquidGlassCapsule(
                accent: accent,
                intensity: intensity,
                interactive: interactive
            )
        )
    }

    func dreamRefractiveLiquidGlassRounded(
        cornerRadius: CGFloat = 22,
        accent: Color = DreamTheme.mistBlue,
        intensity: Double = 0.75,
        interactive: Bool = false
    ) -> some View {
        modifier(
            RefractiveLiquidGlassRounded(
                cornerRadius: cornerRadius,
                accent: accent,
                intensity: intensity,
                interactive: interactive
            )
        )
    }
}

struct SectionHeader: View {
    let title: String
    var trailing: AnyView? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(DreamTypography.largeTitle)
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
                .font(DreamTypography.body)
                .foregroundStyle(DreamTheme.secondaryText)
                .multilineTextAlignment(.center)

            Button(action: action) {
                Text(actionTitle)
                    .font(DreamTypography.callout)
                    .foregroundStyle(DreamTheme.moonWhite)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .dreamRefractiveLiquidGlassCapsule(
                        accent: DreamTheme.warmApricot,
                        intensity: 0.88,
                        interactive: true
                    )
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
    var usesLiquidGlass: Bool = false
    /// When set, chip stretches to this width (equal-width tag rows).
    var fixedWidth: CGFloat? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(selected ? DreamTypography.callout.bold() : DreamTypography.callout)
                .foregroundStyle(foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: fixedWidth == nil ? nil : .infinity)
                .padding(.horizontal, fixedWidth == nil ? 14 : 8)
                .padding(.vertical, fixedWidth == nil ? 8 : 11)
                .background {
                    if !usesLiquidGlass {
                        Capsule()
                            .fill(selected ? DreamTheme.moonWhite.opacity(0.92) : Color.white.opacity(0.08))
                    }
                }
                .modifier(LiquidGlassChipBackground(enabled: usesLiquidGlass, selected: selected))
                .frame(width: fixedWidth)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var foreground: Color {
        if usesLiquidGlass {
            return selected ? DreamTheme.moonWhite : DreamTheme.moonWhite.opacity(0.72)
        }
        return selected ? DreamTheme.midnight : DreamTheme.moonWhite.opacity(0.8)
    }
}

private struct LiquidGlassChipBackground: ViewModifier {
    var enabled: Bool
    var selected: Bool

    func body(content: Content) -> some View {
        if enabled {
            content
                .scaleEffect(selected ? 1.05 : 1)
                .animation(.spring(response: 0.28, dampingFraction: 0.78), value: selected)
                .dreamRefractiveLiquidGlassCapsule(
                    accent: selected ? DreamTheme.warmApricot : DreamTheme.mistBlue,
                    intensity: selected ? 0.95 : 0.62,
                    interactive: true
                )
        } else {
            content
        }
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
                .font(selected ? DreamTypography.callout : DreamTypography.caption)
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
