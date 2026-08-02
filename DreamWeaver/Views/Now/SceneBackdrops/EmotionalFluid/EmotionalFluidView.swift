import SwiftUI

/// Immersive emotional fluid color space — continuous soft flow, Apple-quiet, no chrome.
/// Standalone: embed with `EmotionalFluidView()`.
/// Scene backdrop: pass `isPlaying` / `reduceMotion` from Now.
struct EmotionalFluidView: View {
    var initialSceneType: FluidSceneType = .cloud
    var isPlaying: Bool = true
    var reduceMotion: Bool = false

    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var paletteManager = ColorPaletteManager(
        paletteInterval: 20,
        morphPeriod: 11
    )
    @State private var didBootstrap = false
    @State private var lastAudioType: FluidSceneType?

    /// Visual-first: keep drifting even when audio is paused.
    private var animationActive: Bool {
        !reduceMotion && scenePhase == .active
    }

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: reduceMotion ? 1.0 / 4.0 : 1.0 / 30.0,
                paused: !animationActive
            )
        ) { timeline in
            let now = timeline.date
            let sample = paletteManager.sample(at: now)
            let t = now.timeIntervalSinceReferenceDate

            Canvas { context, size in
                drawFluid(
                    context: &context,
                    size: size,
                    sample: sample,
                    t: t
                )
            }
            // Hard RGB ceiling: even additive highlights cannot reach pure white.
            .colorMultiply(Color(white: 0.88))
            .onChange(of: Int(t)) { _, _ in
                paletteManager.tick(now: now, active: animationActive)
                if lastAudioType != sample.sceneType {
                    lastAudioType = sample.sceneType
                    FluidSceneAudioManager.shared.playSceneSound(sceneType: sample.sceneType)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            if !didBootstrap {
                paletteManager.setSceneType(initialSceneType)
                FluidSceneAudioManager.shared.playSceneSound(sceneType: initialSceneType)
                lastAudioType = initialSceneType
                didBootstrap = true
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Drawing

    private func drawFluid(
        context: inout GraphicsContext,
        size: CGSize,
        sample: ColorPaletteManager.Sample,
        t: TimeInterval
    ) {
        let palette = sample.palette

        // Moving multi-stop base — never a single flat primary wash.
        drawLivingBase(context: &context, size: size, palette: palette, t: t)

        let mix = sample.modeMix
        if mix <= 0.001 {
            drawMode(sample.sceneType, context: &context, size: size, palette: palette, phase: sample.morphPhase, t: t, opacityScale: 1)
        } else if mix >= 0.999 {
            drawMode(sample.nextSceneType, context: &context, size: size, palette: palette, phase: sample.morphPhase, t: t, opacityScale: 1)
        } else {
            // Crossfade draw algorithms while colors already blend — no mode pop.
            drawMode(sample.sceneType, context: &context, size: size, palette: palette, phase: sample.morphPhase, t: t, opacityScale: 1 - mix)
            drawMode(sample.nextSceneType, context: &context, size: size, palette: palette, phase: sample.morphPhase, t: t, opacityScale: mix)
        }

        drawEnergySurge(
            context: &context,
            size: size,
            palette: palette,
            phase: sample.morphPhase,
            t: t
        )
    }

    private func drawMode(
        _ type: FluidSceneType,
        context: inout GraphicsContext,
        size: CGSize,
        palette: FluidColorPalette,
        phase: Double,
        t: TimeInterval,
        opacityScale: Double
    ) {
        guard opacityScale > 0.01 else { return }
        switch type {
        case .cloud:
            drawCloud(context: &context, size: size, palette: palette, phase: phase, t: t, opacityScale: opacityScale)
        case .water:
            drawWater(context: &context, size: size, palette: palette, phase: phase, t: t, opacityScale: opacityScale)
        case .flame:
            drawFlame(context: &context, size: size, palette: palette, phase: phase, t: t, opacityScale: opacityScale)
        }
    }

    /// Layered drifting base so no single hue owns the whole frame.
    private func drawLivingBase(
        context: inout GraphicsContext,
        size: CGSize,
        palette: FluidColorPalette,
        t: TimeInterval
    ) {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(palette.primary.opacity(0.82)))

        let bands: [(seed: Double, sx: Double, sy: Double, color: Color, opacity: Double)] = [
            (0.10, 0.068, 0.032, palette.secondary, 0.52),
            (0.55, -0.056, 0.044, palette.tertiary, 0.34),
            (0.80, 0.046, -0.052, palette.highlight, 0.30),
            (0.30, -0.050, -0.038, palette.highlight, 0.24)
        ]
        let blur = min(size.width, size.height) * 0.12
        for band in bands {
            // Continuous UV (do not wrap here) — tiling painter handles seams.
            Self.paintToroidalBlob(
                context: &context,
                size: size,
                u: band.seed + t * band.sx,
                v: band.seed * 1.7 + t * band.sy,
                width: size.width * 1.15,
                height: size.height * 0.72,
                color: band.color.opacity(band.opacity),
                blur: blur
            )
        }
    }

    private func drawCloud(
        context: inout GraphicsContext,
        size: CGSize,
        palette: FluidColorPalette,
        phase: Double,
        t: TimeInterval,
        opacityScale: Double
    ) {
        struct Blob {
            var seed: Double
            var speedX: Double
            var speedY: Double
            var w: CGFloat
            var h: CGFloat
            var tone: Int // 0 primary, 1 secondary, 2 tertiary, 3 highlight
            var opacity: Double
            var orbit: Double
        }

        // Smaller masses + mixed tones so one hue cannot dominate.
        let blobs: [Blob] = [
            Blob(seed: 0.12, speedX: 0.045, speedY: 0.028, w: 0.55, h: 0.42, tone: 1, opacity: 0.50, orbit: 0.07),
            Blob(seed: 0.41, speedX: -0.038, speedY: 0.042, w: 0.48, h: 0.40, tone: 2, opacity: 0.36, orbit: 0.08),
            Blob(seed: 0.67, speedX: 0.032, speedY: -0.036, w: 0.58, h: 0.46, tone: 1, opacity: 0.40, orbit: 0.06),
            Blob(seed: 0.23, speedX: -0.050, speedY: -0.024, w: 0.40, h: 0.36, tone: 3, opacity: 0.30, orbit: 0.09),
            Blob(seed: 0.88, speedX: 0.042, speedY: 0.048, w: 0.46, h: 0.38, tone: 1, opacity: 0.34, orbit: 0.07),
            Blob(seed: 0.55, speedX: -0.028, speedY: 0.055, w: 0.44, h: 0.34, tone: 3, opacity: 0.28, orbit: 0.08),
            Blob(seed: 0.74, speedX: 0.055, speedY: -0.040, w: 0.38, h: 0.42, tone: 1, opacity: 0.32, orbit: 0.09),
            Blob(seed: 0.33, speedX: -0.044, speedY: -0.046, w: 0.50, h: 0.36, tone: 3, opacity: 0.26, orbit: 0.07),
            Blob(seed: 0.06, speedX: 0.036, speedY: 0.033, w: 0.36, h: 0.40, tone: 1, opacity: 0.30, orbit: 0.10),
            Blob(seed: 0.91, speedX: -0.034, speedY: 0.038, w: 0.42, h: 0.32, tone: 2, opacity: 0.24, orbit: 0.08)
        ]

        let blur = min(size.width, size.height) * 0.09
        let morph = phase * (.pi * 2)

        for blob in blobs {
            let wx = sin(t * 1.25 + blob.seed * 9) * blob.orbit * 1.35
            let wy = cos(t * 1.05 + blob.seed * 7) * blob.orbit * 1.35
            // Keep UV continuous across frames — wrapping is only in the painter.
            let u = blob.seed + t * blob.speedX * 1.55 + wx
            let v = blob.seed * 1.37 + t * blob.speedY * 1.55 + wy
            let breathe = 1.0 + sin(morph + t * 1.35 + blob.seed * 5) * 0.25
            let color = toneColor(blob.tone, palette: palette)

            Self.paintToroidalBlob(
                context: &context,
                size: size,
                u: u,
                v: v,
                width: blob.w * size.width * breathe,
                height: blob.h * size.height * breathe,
                color: color.opacity(min(blob.opacity * 1.22, 0.68) * opacityScale),
                blur: blur
            )
        }
    }

    private func drawWater(
        context: inout GraphicsContext,
        size: CGSize,
        palette: FluidColorPalette,
        phase: Double,
        t: TimeInterval,
        opacityScale: Double
    ) {
        let cx = size.width * (0.5 + sin(t * 0.42) * 0.22 + cos(t * 0.26) * 0.10)
        let cy = size.height * (0.48 + cos(t * 0.38) * 0.20 + sin(t * 0.29) * 0.09)
        let maxR = hypot(size.width, size.height) * 0.58
        let blur = min(size.width, size.height) * 0.08

        for i in 0..<8 {
            let cycle = 7.0 + Double(i) * 1.4
            let local = Self.wrap01(t / cycle + Double(i) * 0.11)
            let expand = Self.smoothstep(local)
            let fade = sin(local * .pi)
            let r = maxR * (0.10 + expand * 0.72)
            let color: Color = {
                switch i % 4 {
                case 0: return palette.primary
                case 1: return palette.secondary
                case 2: return palette.tertiary
                default: return palette.highlight
                }
            }()
            let opacity = (0.38 - Double(i) * 0.026) * fade * opacityScale

            var soft = context
            soft.addFilter(.blur(radius: blur))
            soft.fill(
                Path(ellipseIn: CGRect(
                    x: cx - r,
                    y: cy - r * 0.80,
                    width: r * 2,
                    height: r * 1.60
                )),
                with: .color(color.opacity(max(0, opacity)))
            )
            soft.stroke(
                Path(ellipseIn: CGRect(
                    x: cx - r,
                    y: cy - r * 0.80,
                    width: r * 2,
                    height: r * 1.60
                )),
                with: .color(color.opacity(max(0, opacity * 1.35))),
                lineWidth: max(1.5, min(size.width, size.height) * 0.006)
            )
        }

        // Extra drifting accents so center rings don't monopolize hue.
        for j in 0..<4 {
            let seed = 0.2 + Double(j) * 0.19
            let color = j % 4 == 0
                ? palette.primary
                : (j % 4 == 1
                    ? palette.secondary
                    : (j % 4 == 2 ? palette.tertiary : palette.highlight))
            Self.paintToroidalBlob(
                context: &context,
                size: size,
                u: seed + t * (0.04 + Double(j) * 0.008),
                v: 0.35 + seed + t * (0.03 - Double(j) * 0.006),
                width: size.width * (0.34 + CGFloat(j) * 0.04),
                height: size.height * (0.28 + CGFloat(j) * 0.03),
                color: color.opacity(0.20 * opacityScale),
                blur: min(size.width, size.height) * 0.11
            )
        }
    }

    private func drawFlame(
        context: inout GraphicsContext,
        size: CGSize,
        palette: FluidColorPalette,
        phase: Double,
        t: TimeInterval,
        opacityScale: Double
    ) {
        struct Ember {
            var seed: Double
            var riseSpeed: Double
            var swayAmp: Double
            var w: CGFloat
            var h: CGFloat
            var tone: Int
            var opacity: Double
        }

        let embers: [Ember] = [
            Ember(seed: 0.50, riseSpeed: 0.10, swayAmp: 0.10, w: 0.46, h: 0.38, tone: 1, opacity: 0.48),
            Ember(seed: 0.28, riseSpeed: 0.13, swayAmp: 0.12, w: 0.34, h: 0.32, tone: 2, opacity: 0.36),
            Ember(seed: 0.72, riseSpeed: 0.12, swayAmp: 0.11, w: 0.36, h: 0.34, tone: 3, opacity: 0.32),
            Ember(seed: 0.40, riseSpeed: 0.15, swayAmp: 0.14, w: 0.30, h: 0.30, tone: 1, opacity: 0.38),
            Ember(seed: 0.62, riseSpeed: 0.16, swayAmp: 0.13, w: 0.28, h: 0.28, tone: 3, opacity: 0.28),
            Ember(seed: 0.18, riseSpeed: 0.11, swayAmp: 0.10, w: 0.38, h: 0.33, tone: 1, opacity: 0.30),
            Ember(seed: 0.84, riseSpeed: 0.14, swayAmp: 0.15, w: 0.26, h: 0.30, tone: 3, opacity: 0.26),
            Ember(seed: 0.36, riseSpeed: 0.12, swayAmp: 0.09, w: 0.32, h: 0.36, tone: 1, opacity: 0.30),
            Ember(seed: 0.58, riseSpeed: 0.17, swayAmp: 0.12, w: 0.24, h: 0.26, tone: 2, opacity: 0.22),
            Ember(seed: 0.46, riseSpeed: 0.09, swayAmp: 0.08, w: 0.50, h: 0.34, tone: 1, opacity: 0.24)
        ]

        let blur = min(size.width, size.height) * 0.085

        for ember in embers {
            let sway = sin(t * 2.2 + ember.seed * 12) * ember.swayAmp * 1.28
                + cos(t * 1.65 + ember.seed * 8) * ember.swayAmp * 0.72
            // Continuous ascent in v; toroidal painter brings it back from the bottom.
            let u = ember.seed + sway
            let v = 1.2 - (t * ember.riseSpeed * 1.42 + ember.seed)
            let breathe = 1.0 + sin(t * 1.9 + ember.seed * 6 + phase * .pi) * 0.28
            let color = toneColor(ember.tone, palette: palette)

            Self.paintToroidalBlob(
                context: &context,
                size: size,
                u: u,
                v: v,
                width: ember.w * size.width * breathe,
                height: ember.h * size.height * breathe,
                color: color.opacity(min(ember.opacity * 1.25, 0.68) * opacityScale),
                blur: blur
            )
        }
    }

    /// Additive moving highlights add contrast and a stronger sense of depth
    /// without introducing flashing or discontinuous cuts.
    private func drawEnergySurge(
        context: inout GraphicsContext,
        size: CGSize,
        palette: FluidColorPalette,
        phase: Double,
        t: TimeInterval
    ) {
        var energy = context
        // Screen keeps the energetic glow but is less prone to additive clipping.
        energy.blendMode = .screen

        let pulse = 0.5 + 0.5 * sin(phase * .pi * 2 + t * 1.6)
        let blur = min(size.width, size.height) * 0.055

        Self.paintToroidalBlob(
            context: &energy,
            size: size,
            u: 0.18 + t * 0.095 + sin(t * 0.72) * 0.12,
            v: 0.28 - t * 0.070 + cos(t * 0.64) * 0.10,
            width: size.width * (0.58 + pulse * 0.18),
            height: size.height * (0.22 + pulse * 0.08),
            color: palette.highlight.opacity(0.15 + pulse * 0.10),
            blur: blur
        )

        Self.paintToroidalBlob(
            context: &energy,
            size: size,
            u: 0.72 - t * 0.082 + cos(t * 0.58) * 0.14,
            v: 0.68 + t * 0.062 + sin(t * 0.81) * 0.11,
            width: size.width * (0.46 + (1 - pulse) * 0.20),
            height: size.height * (0.18 + (1 - pulse) * 0.09),
            color: palette.tertiary.opacity(0.13 + (1 - pulse) * 0.09),
            blur: blur * 1.15
        )
    }

    // MARK: - Helpers

    private func toneColor(_ tone: Int, palette: FluidColorPalette) -> Color {
        switch tone {
        case 3: return palette.highlight
        case 2: return palette.tertiary
        case 1: return palette.secondary
        default: return palette.primary
        }
    }

    /// Seamless screen-torus paint.
    /// - Important: `u`/`v` must be **continuous** over time (no per-frame wrap).
    /// - Draws a 3×3 tile neighborhood so edge **and corner** exits never pop.
    /// - Cull margin includes blur radius (blur extends past the ellipse bounds).
    private static func paintToroidalBlob(
        context: inout GraphicsContext,
        size: CGSize,
        u: Double,
        v: Double,
        width: CGFloat,
        height: CGFloat,
        color: Color,
        blur: CGFloat
    ) {
        guard size.width > 1, size.height > 1 else { return }

        // Fractional position inside one screen period. When u crosses an integer,
        // frac jumps 0.99→0.01 while the +1 tile simultaneously carries the mass —
        // together they are continuous on a torus.
        let fracU = wrap01(u)
        let fracV = wrap01(v)
        let baseX = CGFloat(fracU) * size.width
        let baseY = CGFloat(fracV) * size.height

        // How many neighbor tiles are needed so a large / heavily blurred blob
        // never loses coverage when straddling an edge or corner.
        let tilesX = max(1, Int(ceil((width * 0.5 + blur * 2.5) / size.width)) + 1)
        let tilesY = max(1, Int(ceil((height * 0.5 + blur * 2.5) / size.height)) + 1)
        let margin = max(width, height) * 0.5 + blur * 2.5
        let view = CGRect(
            x: -margin,
            y: -margin,
            width: size.width + margin * 2,
            height: size.height + margin * 2
        )

        for dy in -tilesY...tilesY {
            for dx in -tilesX...tilesX {
                let center = CGPoint(
                    x: baseX + CGFloat(dx) * size.width,
                    y: baseY + CGFloat(dy) * size.height
                )
                let rect = CGRect(
                    x: center.x - width * 0.5,
                    y: center.y - height * 0.5,
                    width: width,
                    height: height
                )
                guard view.intersects(rect) else { continue }

                var soft = context
                soft.addFilter(.blur(radius: blur))
                soft.fill(Path(ellipseIn: rect), with: .color(color))
            }
        }
    }

    private static func wrap01(_ value: Double) -> Double {
        let r = value.truncatingRemainder(dividingBy: 1)
        return r < 0 ? r + 1 : r
    }

    private static func smoothstep(_ x: Double) -> Double {
        let t = max(0, min(1, x))
        return t * t * (3 - 2 * t)
    }
}

#Preview("Emotional Fluid") {
    EmotionalFluidView()
}
