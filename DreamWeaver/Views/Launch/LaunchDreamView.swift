import SwiftUI

struct LaunchDreamView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    @State private var logoProgress: CGFloat = 0
    @State private var overallOpacity = 1.0

    private var reduceMotion: Bool {
        appState.reduceMotion || systemReduceMotion
    }

    var body: some View {
        let colors = LaunchSceneColors(scenePalette: appState.currentScene.palette)

        ZStack {
            colors.backgroundGradient

            DreamWeaverDrawnMark(progress: logoProgress, colors: colors)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(.easeInOut(duration: 0.45), value: appState.currentScene.palette)
        .opacity(overallOpacity)
        .ignoresSafeArea()
        .onAppear(perform: runLaunchSequence)
    }

    private func runLaunchSequence() {
        // The three equal writing windows share a 1.2-second master timeline;
        // the mark applies its own gentle ease-in/ease-out so every stroke
        // still feels hand-drawn.
        let drawingDuration: Double = reduceMotion ? 0 : 1.2
        let holdDuration: Double = reduceMotion ? 0.28 : 0.56
        let dissolveDuration: Double = reduceMotion ? 0.20 : 0.68

        if reduceMotion {
            logoProgress = 1
        } else {
            withAnimation(.linear(duration: drawingDuration)) {
                logoProgress = 1
            }
        }

        Task {
            try? await Task.sleep(nanoseconds: UInt64((drawingDuration + holdDuration) * 1_000_000_000))
            withAnimation(.easeInOut(duration: dissolveDuration)) {
                overallOpacity = 0
            }
            try? await Task.sleep(nanoseconds: UInt64(dissolveDuration * 1_000_000_000))
            appState.finishLaunch()
        }
    }
}

/// Extracts the lightest and darkest representative tones from the scene that
/// is already rendered beneath the launch overlay. This also covers scenes
/// delivered by the backend without maintaining a style-specific color table.
private struct LaunchSceneColors {
    let darkHex: UInt32
    let lightHex: UInt32

    init(scenePalette: ScenePalette) {
        let backgroundTones = [scenePalette.top, scenePalette.mid, scenePalette.bottom]
        let dark = backgroundTones.min {
            Self.relativeLuminance($0) < Self.relativeLuminance($1)
        } ?? scenePalette.bottom

        let extractedLight = (backgroundTones + [scenePalette.accent]).max {
            Self.relativeLuminance($0) < Self.relativeLuminance($1)
        } ?? scenePalette.accent

        darkHex = dark
        // Preserve the extracted hue while guaranteeing that the drawn mark
        // remains legible for low-contrast palettes supplied by remote scenes.
        lightHex = Self.relativeLuminance(extractedLight) - Self.relativeLuminance(dark) < 0.16
            ? Self.blend(extractedLight, with: 0xFFFFFF, amount: 0.42)
            : extractedLight
    }

    var darkColor: Color { Color(hex: darkHex) }
    var lightColor: Color { Color(hex: lightHex) }

    var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                darkColor,
                Color(hex: Self.blend(darkHex, with: lightHex, amount: 0.10)),
                darkColor
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var markGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: Self.blend(lightHex, with: 0xFFFFFF, amount: 0.12)),
                lightColor,
                Color(hex: Self.blend(lightHex, with: darkHex, amount: 0.18)),
                lightColor
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private static func relativeLuminance(_ hex: UInt32) -> Double {
        func linearized(_ component: UInt32) -> Double {
            let value = Double(component) / 255
            return value <= 0.04045
                ? value / 12.92
                : pow((value + 0.055) / 1.055, 2.4)
        }

        let red = linearized((hex >> 16) & 0xFF)
        let green = linearized((hex >> 8) & 0xFF)
        let blue = linearized(hex & 0xFF)
        return red * 0.2126 + green * 0.7152 + blue * 0.0722
    }

    private static func blend(_ source: UInt32, with target: UInt32, amount: Double) -> UInt32 {
        func component(_ shift: UInt32) -> UInt32 {
            let sourceValue = Double((source >> shift) & 0xFF)
            let targetValue = Double((target >> shift) & 0xFF)
            return UInt32((sourceValue + (targetValue - sourceValue) * amount).rounded())
        }

        return (component(16) << 16) | (component(8) << 8) | component(0)
    }
}

private struct DreamWeaverDrawnMark: View {
    let progress: CGFloat
    let colors: LaunchSceneColors

    var body: some View {
        GeometryReader { proxy in
            let width = min(
                proxy.size.width * 0.72,
                proxy.size.height * 0.54,
                340
            )
            let lineWidth = width * 0.09

            ZStack {
                ForEach(DreamWeaverMarkStroke.allCases) { stroke in
                    let completion = strokeCompletion(for: stroke)

                    DreamWeaverMarkPath(stroke: stroke)
                        .trim(from: 0, to: completion)
                        .stroke(
                            colors.lightColor.opacity(0.32),
                            style: StrokeStyle(
                                lineWidth: lineWidth * 1.16,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                        .blur(radius: 9)

                    DreamWeaverMarkPath(stroke: stroke)
                        .trim(from: 0, to: completion)
                        .stroke(
                            colors.markGradient,
                            style: StrokeStyle(
                                lineWidth: lineWidth,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                }
            }
            .frame(width: width, height: width / 0.62)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityLabel("DreamWeaver")
    }

    private func strokeCompletion(for stroke: DreamWeaverMarkStroke) -> CGFloat {
        let window = stroke.revealWindow
        let linearCompletion = min(
            max((progress - window.lowerBound) / (window.upperBound - window.lowerBound), 0),
            1
        )
        // Smoothstep gives each Z a comfortable pen-down and pen-lift without
        // changing its duration relative to the other two marks.
        return linearCompletion * linearCompletion * (3 - 2 * linearCompletion)
    }
}

enum DreamWeaverMarkStroke: CaseIterable, Hashable, Identifiable {
    case upperZ
    case middleZ
    case lowerZ

    var id: Self { self }

    var revealWindow: ClosedRange<CGFloat> {
        switch self {
        case .upperZ: 0...(1 / 3)
        case .middleZ: (1 / 3)...(2 / 3)
        case .lowerZ: (2 / 3)...1
        }
    }
}

struct DreamWeaverMarkPath: Shape {
    let stroke: DreamWeaverMarkStroke

    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(
                x: rect.minX + rect.width * x / 300,
                y: rect.minY + rect.height * y / 520
            )
        }

        var path = Path()

        switch stroke {
        case .upperZ:
            path.move(to: point(35, 161))
            path.addCurve(
                to: point(257, 21),
                control1: point(51, 116),
                control2: point(137, 42)
            )
            path.addCurve(
                to: point(112, 157),
                control1: point(235, 48),
                control2: point(126, 127)
            )
            path.addCurve(
                to: point(184, 153),
                control1: point(108, 170),
                control2: point(149, 162)
            )

        case .middleZ:
            path.move(to: point(25, 225))
            path.addCurve(
                to: point(168, 210),
                control1: point(58, 203),
                control2: point(129, 192)
            )
            path.addCurve(
                to: point(47, 357),
                control1: point(142, 244),
                control2: point(67, 311)
            )
            path.addCurve(
                to: point(153, 329),
                control1: point(58, 364),
                control2: point(117, 341)
            )

        case .lowerZ:
            path.move(to: point(76, 394))
            path.addCurve(
                to: point(184, 393),
                control1: point(107, 375),
                control2: point(155, 363)
            )
            path.addCurve(
                to: point(121, 472),
                control1: point(162, 417),
                control2: point(137, 443)
            )
            path.addCurve(
                to: point(254, 510),
                control1: point(145, 513),
                control2: point(213, 528)
            )
        }

        return path
    }
}

#Preview {
    LaunchDreamView()
        .environmentObject(AppState())
}
