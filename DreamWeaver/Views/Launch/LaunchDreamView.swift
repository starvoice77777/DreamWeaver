import SwiftUI

struct LaunchDreamView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    @State private var greeting = MockDataService.greetings.randomElement() ?? "晚上好，今天辛苦了。"
    @State private var greetingOpacity = 0.0
    @State private var gradientShift = false
    @State private var overallOpacity = 1.0

    private var reduceMotion: Bool {
        appState.reduceMotion || systemReduceMotion
    }

    var body: some View {
        ZStack {
            AnimatedLaunchBackground(shift: gradientShift, reduceMotion: reduceMotion)

            Text(greeting)
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(DreamTheme.moonWhite.opacity(0.92))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .opacity(greetingOpacity)
        }
        .opacity(overallOpacity)
        .ignoresSafeArea()
        .onAppear(perform: runLaunchSequence)
    }

    private func runLaunchSequence() {
        if !reduceMotion {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                gradientShift = true
            }
        }

        let fadeIn: Double = reduceMotion ? 0.15 : 0.9
        let hold: Double = reduceMotion ? 0.4 : 1.1
        let fadeOut: Double = reduceMotion ? 0.15 : 0.7
        let exit: Double = reduceMotion ? 0.2 : 0.5

        withAnimation(.easeInOut(duration: fadeIn)) {
            greetingOpacity = 1
        }

        Task {
            try? await Task.sleep(nanoseconds: UInt64((fadeIn + hold) * 1_000_000_000))
            withAnimation(.easeInOut(duration: fadeOut)) {
                greetingOpacity = 0
            }
            try? await Task.sleep(nanoseconds: UInt64((fadeOut + 0.15) * 1_000_000_000))
            withAnimation(.easeInOut(duration: exit)) {
                overallOpacity = 0
            }
            try? await Task.sleep(nanoseconds: UInt64(exit * 1_000_000_000))
            appState.finishLaunch()
        }
    }
}

private struct AnimatedLaunchBackground: View {
    var shift: Bool
    var reduceMotion: Bool

    var body: some View {
        ZStack {
            DreamTheme.midnight
            LinearGradient(
                colors: [
                    Color(hex: 0x11182A),
                    Color(hex: 0x1A2740),
                    Color(hex: 0x2A1E28),
                    Color(hex: 0x080B16)
                ],
                startPoint: shift ? .topLeading : .bottomLeading,
                endPoint: shift ? .bottomTrailing : .topTrailing
            )
            .opacity(0.95)

            Circle()
                .fill(DreamTheme.warmApricot.opacity(0.12))
                .frame(width: 280, height: 280)
                .blur(radius: reduceMotion ? 20 : 50)
                .offset(x: shift ? 60 : -40, y: shift ? -120 : -80)

            Circle()
                .fill(DreamTheme.mistBlue.opacity(0.14))
                .frame(width: 320, height: 320)
                .blur(radius: reduceMotion ? 24 : 60)
                .offset(x: shift ? -80 : 50, y: shift ? 160 : 120)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    LaunchDreamView()
        .environmentObject(AppState())
}
