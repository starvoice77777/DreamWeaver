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
        ZStack {
            Color.black

            DreamWeaverDrawnMark(progress: logoProgress)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .opacity(overallOpacity)
        .ignoresSafeArea()
        .onAppear(perform: runLaunchSequence)
    }

    private func runLaunchSequence() {
        let drawingDuration: Double = reduceMotion ? 0 : 1.65
        let holdDuration: Double = reduceMotion ? 0.28 : 0.62
        let dissolveDuration: Double = reduceMotion ? 0.20 : 0.72

        if reduceMotion {
            logoProgress = 1
        } else {
            withAnimation(.timingCurve(0.22, 0.74, 0.26, 1, duration: drawingDuration)) {
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

private struct DreamWeaverDrawnMark: View {
    let progress: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let width = min(proxy.size.width * 0.72, 340)
            let lineWidth = width * 0.09

            ZStack {
                ForEach(DreamWeaverMarkStroke.allCases) { stroke in
                    let completion = strokeCompletion(for: stroke)

                    DreamWeaverMarkPath(stroke: stroke)
                        .trim(from: 0, to: completion)
                        .stroke(
                            Color(red: 0.85, green: 0.68, blue: 0.43).opacity(0.32),
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
                            goldGradient,
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

    private var goldGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.73, green: 0.55, blue: 0.33),
                Color(red: 0.94, green: 0.80, blue: 0.59),
                Color(red: 0.80, green: 0.60, blue: 0.36),
                Color(red: 0.91, green: 0.74, blue: 0.51)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func strokeCompletion(for stroke: DreamWeaverMarkStroke) -> CGFloat {
        let window = stroke.revealWindow
        return min(
            max((progress - window.lowerBound) / (window.upperBound - window.lowerBound), 0),
            1
        )
    }
}

private enum DreamWeaverMarkStroke: CaseIterable, Hashable, Identifiable {
    case upperSweep
    case upperReturn
    case middleSweep
    case lowerSweep

    var id: Self { self }

    var revealWindow: ClosedRange<CGFloat> {
        switch self {
        case .upperSweep: 0.00...0.31
        case .upperReturn: 0.18...0.48
        case .middleSweep: 0.38...0.73
        case .lowerSweep: 0.65...1.00
        }
    }
}

private struct DreamWeaverMarkPath: Shape {
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
        case .upperSweep:
            path.move(to: point(35, 161))
            path.addCurve(
                to: point(257, 21),
                control1: point(51, 116),
                control2: point(137, 42)
            )

        case .upperReturn:
            path.move(to: point(225, 55))
            path.addCurve(
                to: point(112, 157),
                control1: point(195, 75),
                control2: point(126, 127)
            )
            path.addCurve(
                to: point(184, 153),
                control1: point(108, 170),
                control2: point(149, 162)
            )

        case .middleSweep:
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

        case .lowerSweep:
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
