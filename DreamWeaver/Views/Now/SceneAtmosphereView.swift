import SwiftUI

/// Now-tab full-bleed atmosphere. Routes to per-scene backdrops
/// (`RainyNightView`, Canvas motifs, future audio-reactive stacks).
struct SceneAtmosphereView: View {
    let scene: DreamScene
    var isPlaying: Bool
    var reduceMotion: Bool
    var intensity: Double

    var body: some View {
        SceneBackdropHost(
            scene: scene,
            isPlaying: isPlaying,
            reduceMotion: reduceMotion,
            intensity: intensity
        )
    }
}

/// Procedural Canvas motifs for scenes without a custom layered art stack.
struct SceneAtmosphereCanvas: View {
    let scene: DreamScene
    var isPlaying: Bool
    var reduceMotion: Bool
    var intensity: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1.0 / 8.0 : 1.0 / 30.0, paused: reduceMotion && !isPlaying)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                drawBase(context: context, size: size)
                switch scene.visualStyle {
                case .rainEaves: drawRain(context: &context, size: size, t: t)
                case .fireflies: drawFireflies(context: &context, size: size, t: t)
                case .mistTide: drawTide(context: &context, size: size, t: t)
                case .valleyStream: drawStream(context: &context, size: size, t: t)
                case .moonLake: drawMoonLake(context: &context, size: size, t: t)
                case .starRiver: drawStars(context: &context, size: size, t: t)
                case .warmLamp: drawWarmLamp(context: &context, size: size, t: t)
                case .snowStudy: drawSnow(context: &context, size: size, t: t)
                case .wheatWind: drawWheat(context: &context, size: size, t: t)
                case .cloudBreath: drawCloudBreath(context: &context, size: size, t: t)
                case .summerInsects: drawInsects(context: &context, size: size, t: t)
                case .fireplaceWhisper: drawFire(context: &context, size: size, t: t)
                case .hairCare: drawWarmLamp(context: &context, size: size, t: t)
                case .emotionalFluid: drawCloudBreath(context: &context, size: size, t: t)
                }
            }
        }
        .background(scene.palette.gradient)
        .ignoresSafeArea()
    }

    private func drawBase(context: GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        context.fill(Path(rect), with: .color(scene.palette.bottomColor.opacity(0.35)))

        var glow = context
        glow.addFilter(.blur(radius: reduceMotion ? 12 : 28))
        let glowRect = CGRect(
            x: size.width * 0.15,
            y: size.height * 0.18,
            width: size.width * 0.7,
            height: size.height * 0.35
        )
        glow.fill(
            Path(ellipseIn: glowRect),
            with: .color(scene.palette.accentColor.opacity(0.16 * intensity))
        )
    }

    private func drawRain(context: inout GraphicsContext, size: CGSize, t: Double) {
        let count = reduceMotion ? 28 : 55
        for i in 0..<count {
            let seed = Double(i) * 17.13
            let x = (seed * 37).truncatingRemainder(dividingBy: Double(size.width))
            let speed = 80 + (seed.truncatingRemainder(dividingBy: 60))
            let y = (t * speed + seed * 20).truncatingRemainder(dividingBy: Double(size.height + 40)) - 20
            var path = Path()
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x + 2, y: y + 14))
            context.stroke(path, with: .color(Color.white.opacity(0.18)), lineWidth: 1)

            if i % 9 == 0 {
                let lx = (seed * 11).truncatingRemainder(dividingBy: Double(size.width))
                let ly = size.height * 0.55 + sin(t * 0.4 + seed) * 8
                context.fill(
                    Path(ellipseIn: CGRect(x: lx, y: ly, width: 6, height: 6)),
                    with: .color(DreamTheme.warmApricot.opacity(0.35))
                )
            }
        }

        // Warm window glow
        var warm = context
        warm.addFilter(.blur(radius: 24))
        warm.fill(
            Path(ellipseIn: CGRect(x: size.width * 0.55, y: size.height * 0.62, width: 120, height: 80)),
            with: .color(DreamTheme.warmApricot.opacity(0.22))
        )
    }

    private func drawFireflies(context: inout GraphicsContext, size: CGSize, t: Double) {
        // Soft tree silhouettes
        for i in 0..<5 {
            let x = size.width * (0.08 + CGFloat(i) * 0.2)
            var tree = Path()
            tree.move(to: CGPoint(x: x, y: size.height))
            tree.addLine(to: CGPoint(x: x + 18 + sin(t * 0.2 + Double(i)) * 4, y: size.height * 0.35))
            tree.addLine(to: CGPoint(x: x + 40, y: size.height))
            context.fill(tree, with: .color(Color.black.opacity(0.28)))
        }

        let count = reduceMotion ? 10 : 18
        for i in 0..<count {
            let seed = Double(i) * 13.7
            let x = size.width * 0.1 + CGFloat((sin(t * 0.35 + seed) * 0.5 + 0.5) * Double(size.width * 0.8))
            let y = size.height * 0.25 + CGFloat((cos(t * 0.28 + seed * 0.7) * 0.5 + 0.5) * Double(size.height * 0.45))
            let pulse = (sin(t * 2 + seed) * 0.5 + 0.5)
            context.fill(
                Path(ellipseIn: CGRect(x: x, y: y, width: 4 + pulse * 2, height: 4 + pulse * 2)),
                with: .color(Color(hex: 0xC8E6A0).opacity(0.35 + pulse * 0.45))
            )
        }
    }

    private func drawTide(context: inout GraphicsContext, size: CGSize, t: Double) {
        for i in 0..<6 {
            let y = size.height * 0.55 + CGFloat(i) * 28
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            for x in stride(from: 0, through: size.width, by: 8) {
                let wave = sin(t * 0.7 + Double(x) * 0.02 + Double(i) * 0.6) * (8 + Double(i))
                path.addLine(to: CGPoint(x: x, y: y + wave))
            }
            context.stroke(path, with: .color(Color.white.opacity(0.08 + Double(i) * 0.02)), lineWidth: 1.5)
        }

        var haze = context
        haze.addFilter(.blur(radius: 30))
        haze.fill(
            Path(ellipseIn: CGRect(x: size.width * 0.2, y: size.height * 0.25, width: size.width * 0.6, height: 100)),
            with: .color(Color.white.opacity(0.08))
        )
    }

    private func drawStream(context: inout GraphicsContext, size: CGSize, t: Double) {
        var path = Path()
        let mid = size.width * 0.5
        path.move(to: CGPoint(x: mid, y: size.height * 0.2))
        for y in stride(from: size.height * 0.2, through: size.height, by: 6) {
            let wobble = sin(t * 1.2 + Double(y) * 0.04) * 18
            path.addLine(to: CGPoint(x: mid + wobble, y: y))
        }
        context.stroke(path, with: .color(Color(hex: 0x7FB8A8).opacity(0.35)), lineWidth: 3)

        for i in 0..<12 {
            let seed = Double(i) * 9
            let y = (t * 40 + seed * 30).truncatingRemainder(dividingBy: Double(size.height * 0.8)) + size.height * 0.2
            let x = mid + sin(t + seed) * 16
            context.fill(
                Path(ellipseIn: CGRect(x: x, y: y, width: 3, height: 6)),
                with: .color(Color.white.opacity(0.25))
            )
        }
    }

    private func drawMoonLake(context: inout GraphicsContext, size: CGSize, t: Double) {
        let moon = CGRect(x: size.width * 0.62, y: size.height * 0.16, width: 70, height: 70)
        context.fill(Path(ellipseIn: moon), with: .color(DreamTheme.moonWhite.opacity(0.85)))
        var soft = context
        soft.addFilter(.blur(radius: 20))
        soft.fill(Path(ellipseIn: moon.insetBy(dx: -20, dy: -20)), with: .color(DreamTheme.moonWhite.opacity(0.2)))

        for i in 0..<4 {
            let y = size.height * 0.62 + CGFloat(i) * 16
            var path = Path()
            path.move(to: CGPoint(x: size.width * 0.15, y: y))
            for x in stride(from: size.width * 0.15, through: size.width * 0.85, by: 10) {
                let w = sin(t * 0.5 + Double(x) * 0.03 + Double(i)) * 4
                path.addLine(to: CGPoint(x: x, y: y + w))
            }
            context.stroke(path, with: .color(DreamTheme.moonWhite.opacity(0.12)), lineWidth: 1)
        }
    }

    private func drawStars(context: inout GraphicsContext, size: CGSize, t: Double) {
        let count = reduceMotion ? 40 : 80
        for i in 0..<count {
            let seed = Double(i) * 12.9898
            let x = (sin(seed) * 0.5 + 0.5) * size.width
            let y = (cos(seed * 1.3) * 0.5 + 0.5) * size.height * 0.75
            let twinkle = (sin(t * 1.5 + seed) * 0.5 + 0.5)
            context.fill(
                Path(ellipseIn: CGRect(x: x, y: y, width: 1.5 + twinkle, height: 1.5 + twinkle)),
                with: .color(Color.white.opacity(0.25 + twinkle * 0.5))
            )
        }

        // Slow river band
        var band = Path()
        band.move(to: CGPoint(x: 0, y: size.height * 0.45))
        for x in stride(from: 0, through: size.width, by: 12) {
            let y = size.height * 0.45 + sin(t * 0.25 + Double(x) * 0.01) * 30 + Double(x) * 0.08
            band.addLine(to: CGPoint(x: x, y: y))
        }
        context.stroke(band, with: .color(Color(hex: 0x9AA6D8).opacity(0.25)), lineWidth: 18)
    }

    private func drawWarmLamp(context: inout GraphicsContext, size: CGSize, t: Double) {
        let pulse = (sin(t * 0.8) * 0.5 + 0.5)
        var glow = context
        glow.addFilter(.blur(radius: 35))
        glow.fill(
            Path(ellipseIn: CGRect(x: size.width * 0.3, y: size.height * 0.35, width: size.width * 0.4, height: size.width * 0.4)),
            with: .color(DreamTheme.warmApricot.opacity(0.2 + pulse * 0.1))
        )
        context.fill(
            Path(ellipseIn: CGRect(x: size.width * 0.46, y: size.height * 0.48, width: 28, height: 28)),
            with: .color(DreamTheme.warmApricot.opacity(0.7))
        )
    }

    private func drawSnow(context: inout GraphicsContext, size: CGSize, t: Double) {
        let count = reduceMotion ? 24 : 50
        for i in 0..<count {
            let seed = Double(i) * 19.1
            let x = (seed * 29 + sin(t * 0.3 + seed) * 20).truncatingRemainder(dividingBy: Double(size.width))
            let y = (t * (20 + seed.truncatingRemainder(dividingBy: 25)) + seed * 40)
                .truncatingRemainder(dividingBy: Double(size.height + 20)) - 10
            context.fill(
                Path(ellipseIn: CGRect(x: x, y: y, width: 3, height: 3)),
                with: .color(Color.white.opacity(0.45))
            )
        }
    }

    private func drawWheat(context: inout GraphicsContext, size: CGSize, t: Double) {
        for i in 0..<16 {
            let x = size.width * (0.05 + CGFloat(i) / 16.0)
            let sway = sin(t * 0.9 + Double(i) * 0.4) * 10
            var path = Path()
            path.move(to: CGPoint(x: x, y: size.height))
            path.addQuadCurve(
                to: CGPoint(x: x + sway, y: size.height * 0.55),
                control: CGPoint(x: x + sway * 0.5, y: size.height * 0.75)
            )
            context.stroke(path, with: .color(Color(hex: 0xC8B070).opacity(0.35)), lineWidth: 2)
        }
    }

    private func drawCloudBreath(context: inout GraphicsContext, size: CGSize, t: Double) {
        let expand = (sin(t * 0.6) * 0.5 + 0.5)
        for i in 0..<3 {
            var mist = context
            mist.addFilter(.blur(radius: 40))
            let w = size.width * (0.45 + expand * 0.15)
            mist.fill(
                Path(ellipseIn: CGRect(
                    x: size.width * 0.5 - w / 2,
                    y: size.height * (0.3 + CGFloat(i) * 0.12),
                    width: w,
                    height: 90
                )),
                with: .color(Color.white.opacity(0.06 + Double(i) * 0.02))
            )
        }
    }

    private func drawInsects(context: inout GraphicsContext, size: CGSize, t: Double) {
        let count = reduceMotion ? 12 : 22
        for i in 0..<count {
            let seed = Double(i) * 8.3
            let x = size.width * 0.1 + CGFloat((sin(t * 1.8 + seed) * 0.5 + 0.5) * Double(size.width * 0.8))
            let y = size.height * 0.4 + CGFloat((cos(t * 2.1 + seed) * 0.5 + 0.5) * Double(size.height * 0.35))
            context.fill(
                Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)),
                with: .color(Color(hex: 0x88C878).opacity(0.55))
            )
        }
    }

    private func drawFire(context: inout GraphicsContext, size: CGSize, t: Double) {
        for i in 0..<5 {
            let pulse = (sin(t * (1.5 + Double(i) * 0.2) + Double(i)) * 0.5 + 0.5)
            var flame = context
            flame.addFilter(.blur(radius: 12))
            let h = 40 + pulse * 50 + Double(i) * 8
            flame.fill(
                Path(ellipseIn: CGRect(
                    x: size.width * 0.5 - 20 + CGFloat(i - 2) * 8,
                    y: size.height * 0.62 - h,
                    width: 24 + pulse * 10,
                    height: h
                )),
                with: .color(Color(hex: 0xE09060).opacity(0.18 + pulse * 0.15))
            )
        }
        context.fill(
            Path(ellipseIn: CGRect(x: size.width * 0.42, y: size.height * 0.68, width: size.width * 0.16, height: 24)),
            with: .color(Color(hex: 0xE09060).opacity(0.45))
        )
    }
}

#Preview {
    SceneAtmosphereView(
        scene: MockDataService.makeScenes()[0],
        isPlaying: true,
        reduceMotion: false,
        intensity: 0.7
    )
}
