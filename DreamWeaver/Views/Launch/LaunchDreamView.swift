import SwiftUI

struct LaunchDreamView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    @State private var greeting = ""
    @State private var greetingOpacity = 0.0
    @State private var gradientShift = false
    @State private var overallOpacity = 1.0

    private var reduceMotion: Bool {
        appState.reduceMotion || systemReduceMotion
    }

    var body: some View {
        ZStack {
            AnimatedLaunchBackground(
                palette: appState.currentScene.palette,
                shift: gradientShift,
                reduceMotion: reduceMotion
            )

            Text(greeting.isEmpty ? " " : greeting)
                .font(DreamTypography.pageTitle)
                .foregroundStyle(DreamTheme.moonWhite.opacity(0.92))
                .shadow(
                    color: appState.currentScene.palette.accentColor.opacity(0.22),
                    radius: 12
                )
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .opacity(greetingOpacity)
        }
        .opacity(overallOpacity)
        .ignoresSafeArea()
        .onAppear(perform: runLaunchSequence)
    }

    private func runLaunchSequence() {
        greeting = appState.contentService.randomGreeting()
        if !reduceMotion {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                gradientShift = true
            }
        }

        let fadeIn: Double = reduceMotion ? 0.15 : 0.9
        let hold: Double = reduceMotion ? 0.35 : 1.0
        let fadeOutGreeting: Double = reduceMotion ? 0.12 : 0.55
        // Soft dissolve over the already-visible Now scene (crossfade, not black cut).
        let dissolve: Double = reduceMotion ? 0.2 : 1.05

        withAnimation(.easeInOut(duration: fadeIn)) {
            greetingOpacity = 1
        }

        Task {
            try? await Task.sleep(nanoseconds: UInt64((fadeIn + hold) * 1_000_000_000))
            withAnimation(.easeInOut(duration: fadeOutGreeting)) {
                greetingOpacity = 0
            }
            try? await Task.sleep(nanoseconds: UInt64((fadeOutGreeting + 0.08) * 1_000_000_000))
            withAnimation(.easeInOut(duration: dissolve)) {
                overallOpacity = 0
            }
            try? await Task.sleep(nanoseconds: UInt64(dissolve * 1_000_000_000))
            appState.finishLaunch()
        }
    }
}

private struct AnimatedLaunchBackground: View {
    var palette: ScenePalette
    var shift: Bool
    var reduceMotion: Bool

    var body: some View {
        ZStack {
            palette.bottomColor

            LinearGradient(
                colors: [
                    palette.topColor,
                    palette.midColor,
                    palette.bottomColor
                ],
                startPoint: shift ? .topLeading : .bottomLeading,
                endPoint: shift ? .bottomTrailing : .topTrailing
            )
            .opacity(0.98)

            Circle()
                .fill(palette.accentColor.opacity(0.16))
                .frame(width: 280, height: 280)
                .blur(radius: reduceMotion ? 20 : 50)
                .offset(x: shift ? 60 : -40, y: shift ? -120 : -80)

            Circle()
                .fill(palette.midColor.opacity(0.28))
                .frame(width: 320, height: 320)
                .blur(radius: reduceMotion ? 24 : 60)
                .offset(x: shift ? -80 : 50, y: shift ? 160 : 120)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.04),
                    Color.clear,
                    palette.bottomColor.opacity(0.18)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

#Preview {
    LaunchDreamView()
        .environmentObject(AppState())
}
