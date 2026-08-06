import SwiftUI

struct LaunchDreamView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    @State private var logoProgress: CGFloat = 0
    @State private var overallOpacity = 1.0

    /// Uses the exact palette of the scene that will be revealed underneath.
    private var launchColors: LaunchSceneColors {
        LaunchSceneColors(palette: appState.launchScenePalette)
    }

    private var reduceMotion: Bool {
        appState.reduceMotion || systemReduceMotion
    }

    var body: some View {
        ZStack {
            launchColors.backgroundGradient

            DreamWeaverDrawnMark(progress: logoProgress, colors: launchColors)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .opacity(overallOpacity)
        .ignoresSafeArea()
        .onAppear(perform: runLaunchSequence)
    }

    private func runLaunchSequence() {
        logoProgress = 0
        overallOpacity = 1

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

/// Scene-derived launch palette. The background follows the scene gradient and
/// the drawn mark follows the scene accent.
private struct LaunchSceneColors {
    let topHex: UInt32
    let midHex: UInt32
    let bottomHex: UInt32
    let accentHex: UInt32

    init(palette: ScenePalette) {
        topHex = palette.top
        midHex = palette.mid
        bottomHex = palette.bottom
        accentHex = palette.accent
    }

    var darkColor: Color { Color(hex: bottomHex) }
    var lightColor: Color { Color(hex: accentHex) }

    var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: topHex),
                Color(hex: midHex),
                Color(hex: bottomHex)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var markGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: Self.blend(accentHex, with: 0xFFFFFF, amount: 0.12)),
                lightColor,
                Color(hex: Self.blend(accentHex, with: bottomHex, amount: 0.18)),
                lightColor
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
