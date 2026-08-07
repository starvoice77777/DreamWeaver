import SwiftUI

/// One persistent scene backdrop shared by all three root tabs.
///
/// Keeping the source view alive lets the Now artwork continuously lose detail
/// and spread into a color field, then reconstruct from the current animation
/// position when the user returns. No snapshot or second image is swapped in.
struct SharedTabAtmosphereBackground: View {
    let scene: DreamScene
    let selectedTab: AppTab
    let isPlaying: Bool
    let reduceMotion: Bool
    let intensity: Double

    private var abstraction: Double {
        selectedTab == .now ? 0 : 1
    }

    private var profileDepth: Double {
        selectedTab == .profile ? 1 : 0
    }

    private var transitionAnimation: Animation {
        .easeInOut(duration: reduceMotion ? 0.20 : 0.92)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                SceneAtmosphereView(
                    scene: scene,
                    isPlaying: isPlaying && selectedTab == .now,
                    reduceMotion: reduceMotion || selectedTab != .now,
                    intensity: intensity,
                    // Keep the same overscan and device-tilt transform while
                    // moving between tabs. Animation playback may pause, but
                    // the source artwork must not jump before it abstracts.
                    depthMotionEnabled: !reduceMotion
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
                .scaleEffect(
                    reduceMotion ? 1 : CGFloat(1 + abstraction * 0.12)
                )
                .blur(
                    radius: CGFloat(abstraction * (reduceMotion ? 28 : 52)),
                    opaque: true
                )
                .saturation(1 - abstraction * 0.10 - profileDepth * 0.12)
                .contrast(1 - abstraction * 0.06)
                .brightness(
                    abstraction * 0.025 - profileDepth * 0.055
                )

                LinearGradient(
                    colors: [
                        Color.black.opacity(
                            abstraction * (0.08 + profileDepth * 0.08)
                        ),
                        Color.black.opacity(
                            abstraction * (0.18 + profileDepth * 0.10)
                        ),
                        Color.black.opacity(
                            abstraction * (0.40 + profileDepth * 0.12)
                        )
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .animation(transitionAnimation, value: selectedTab)
        .animation(.easeInOut(duration: 0.6), value: scene.id)
        .accessibilityHidden(true)
    }
}
