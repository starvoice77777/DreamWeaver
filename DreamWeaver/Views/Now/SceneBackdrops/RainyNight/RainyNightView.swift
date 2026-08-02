import UIKit

/// Chinese rainy-night atmosphere: 5 stacked layers driven by `CADisplayLink`.
///
/// Z order (bottom → top):
/// 1. Background `bg`
/// 2. Rain droplets
/// 3. Rain occlusion mask
/// 4. Warm lamp radial glow (screen blend)
/// 5. Lamp / frame opacity mask
final class RainyNightView: UIView, SceneBackdropAnimating {
    private var configuration: RainyNightConfiguration

    private let backgroundView = UIImageView()
    private let rainView = RainDropletLayerView()
    private let rainMaskView = UIImageView()
    private let lampGlowView = WarmLampGlowView()
    private let lampMaskView = UIImageView()

    private var displayLink: CADisplayLink?
    private var lampDesignPoint: CGPoint
    private var isActive = true
    private var reduceMotion = false
    private var intensity: CGFloat = 0.85

    init(configuration: RainyNightConfiguration = .rainEaves) {
        self.configuration = configuration
        self.lampDesignPoint = configuration.lampDesignPoint
        super.init(frame: .zero)
        isOpaque = true
        backgroundColor = UIColor(red: 0.07, green: 0.09, blue: 0.14, alpha: 1)
        clipsToBounds = true
        isUserInteractionEnabled = false
        buildLayers()
        reloadAssets()
        applyPlaybackState()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        displayLink?.invalidate()
    }

    // MARK: - Public API

    func updateConfiguration(_ configuration: RainyNightConfiguration) {
        self.configuration = configuration
        lampDesignPoint = configuration.lampDesignPoint
        rainView.dropletCount = configuration.dropletCount
        lampGlowView.baseRadiusDesign = configuration.baseLampRadius
        reloadAssets()
        setNeedsLayout()
    }

    /// Lamp center in the configuration's design coordinates. Call after art shifts.
    func updateLampPosition(_ point: CGPoint) {
        lampDesignPoint = point
        layoutLamp()
    }

    func setActive(_ active: Bool) {
        isActive = active
        applyPlaybackState()
    }

    func setReduceMotion(_ reduce: Bool) {
        reduceMotion = reduce
        rainView.reduceMotion = reduce
        applyPlaybackState()
    }

    func setIntensity(_ intensity: CGFloat) {
        self.intensity = max(0, min(1, intensity))
        rainView.intensity = self.intensity
        lampGlowView.intensity = self.intensity
    }

    func applyAudioLevel(_ level: CGFloat) {
        // Reserved: e.g. couple rain density / lamp flicker to rain track RMS.
        lampGlowView.audioBoost = max(0, min(1, level)) * 0.08
    }

    // MARK: - Lifecycle

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            stopDisplayLink()
        } else {
            applyPlaybackState()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let bounds = self.bounds
        for view in [backgroundView, rainView, rainMaskView, lampGlowView, lampMaskView] {
            view.frame = bounds
        }
        rainView.designSize = configuration.designSize
        rainView.designScale = RainyNightLayout.aspectFillScale(
            design: configuration.designSize,
            bounds: bounds.size
        )
        layoutLamp()
    }

    // MARK: - Setup

    private func buildLayers() {
        for imageView in [backgroundView, rainMaskView, lampMaskView] {
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.backgroundColor = .clear
        }

        rainView.backgroundColor = .clear
        rainView.isOpaque = false
        rainView.dropletCount = configuration.dropletCount

        lampGlowView.backgroundColor = .clear
        lampGlowView.isOpaque = false
        lampGlowView.baseRadiusDesign = configuration.baseLampRadius
        // Screen blend so glow lifts midtones without crushing shadow detail.
        lampGlowView.layer.compositingFilter = "screenBlendMode"

        // Bottom → top
        addSubview(backgroundView)   // 1
        addSubview(rainView)         // 2
        addSubview(rainMaskView)     // 3
        addSubview(lampGlowView)     // 4
        addSubview(lampMaskView)     // 5
    }

    private func reloadAssets() {
        let background = configuration.loadBackground()
        backgroundView.image = background
        rainMaskView.image = configuration.loadRainMask()
        lampMaskView.image = configuration.loadLampMask()

        // If art is missing from the bundle, keep a visible fallback so the
        // layered stack is still diagnosable in Simulator.
        if background == nil {
            backgroundView.backgroundColor = UIColor(red: 0.12, green: 0.18, blue: 0.28, alpha: 1)
            #if DEBUG
            print("[RainyNight] missing background image — check Resources/Scenes/RainEaves/bg.jpg and asset catalog rain_eaves_bg")
            #endif
        } else {
            backgroundView.backgroundColor = .clear
            // Align design space to the actual bitmap aspect when possible.
            let pixel = background!.size
            if pixel.width > 1, pixel.height > 1 {
                let aspect = pixel.width / pixel.height
                let designAspect = configuration.designSize.width / configuration.designSize.height
                if abs(aspect - designAspect) > 0.02 {
                    let old = configuration.designSize
                    var updated = configuration
                    updated.designSize = pixel
                    updated.lampDesignPoint = CGPoint(
                        x: lampDesignPoint.x * pixel.width / old.width,
                        y: lampDesignPoint.y * pixel.height / old.height
                    )
                    updated.baseLampRadius = configuration.baseLampRadius * pixel.width / old.width
                    configuration = updated
                    lampDesignPoint = updated.lampDesignPoint
                    lampGlowView.baseRadiusDesign = updated.baseLampRadius
                }
            }
        }
    }

    private func layoutLamp() {
        let viewPoint = RainyNightLayout.designToView(
            lampDesignPoint,
            design: configuration.designSize,
            bounds: bounds
        )
        let scale = RainyNightLayout.aspectFillScale(
            design: configuration.designSize,
            bounds: bounds.size
        )
        lampGlowView.centerInView = viewPoint
        lampGlowView.pointScale = scale
    }

    // MARK: - Display link

    private func applyPlaybackState() {
        let shouldRun = isActive && window != nil && !reduceMotion
        if shouldRun {
            startDisplayLink()
        } else {
            stopDisplayLink()
            // One static frame for reduce-motion / paused.
            rainView.tick(delta: 0)
            lampGlowView.tick(delta: 0)
        }
        rainView.alpha = isActive ? 1 : 0.35
        lampGlowView.alpha = isActive ? 1 : 0.55
    }

    private func startDisplayLink() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: DisplayLinkProxy(target: self), selector: #selector(DisplayLinkProxy.step(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    fileprivate func handleDisplayLink(_ link: CADisplayLink) {
        let delta = link.duration > 0 ? CGFloat(link.duration) : (1.0 / 60.0)
        // Normalize to ~60fps step so rain speed matches “pt/frame” authoring.
        let frameScale = delta * 60.0
        rainView.tick(delta: frameScale)
        lampGlowView.tick(delta: delta)
    }
}

// MARK: - DisplayLink proxy (avoids retain cycle)

private final class DisplayLinkProxy: NSObject {
    weak var target: RainyNightView?

    init(target: RainyNightView) {
        self.target = target
    }

    @objc func step(_ link: CADisplayLink) {
        target?.handleDisplayLink(link)
    }
}

// MARK: - Layer 2: rain

private final class RainDropletLayerView: UIView {
    struct Droplet {
        var x: CGFloat
        var y: CGFloat
        var length: CGFloat
        var alpha: CGFloat
        var speed: CGFloat
    }

    var dropletCount = 135 {
        didSet { respawnIfNeeded() }
    }
    var reduceMotion = false
    var intensity: CGFloat = 0.85
    var designSize: CGSize = RainyNightConfiguration.specDesignSize
    /// Maps design pt → view pt (Aspect Fill scale).
    var designScale: CGFloat = 1

    private var droplets: [Droplet] = []
    private let windDX: CGFloat = 0.12
    private let windDY: CGFloat = 1.0

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.clear(rect)
        let scale = max(designScale, 0.01)
        ctx.setLineCap(.round)

        for drop in droplets {
            let x = drop.x * scale + (bounds.width - designSize.width * scale) * 0.5
            let y = drop.y * scale + (bounds.height - designSize.height * scale) * 0.5
            let len = drop.length * scale
            let dx = windDX * len
            let dy = windDY * len
            ctx.setStrokeColor(UIColor(white: 0.92, alpha: drop.alpha * intensity).cgColor)
            ctx.setLineWidth(max(0.7, 1.1 * scale * 0.35))
            ctx.beginPath()
            ctx.move(to: CGPoint(x: x, y: y))
            ctx.addLine(to: CGPoint(x: x + dx, y: y + dy))
            ctx.strokePath()
        }
    }

    func tick(delta: CGFloat) {
        if droplets.isEmpty { respawnIfNeeded() }
        let design = designSize
        let margin: CGFloat = 40
        for i in droplets.indices {
            droplets[i].x += windDX * droplets[i].speed * delta
            droplets[i].y += windDY * droplets[i].speed * delta
            if droplets[i].y > design.height + margin || droplets[i].x > design.width + margin {
                droplets[i] = makeDroplet(spawnTop: true)
            }
        }
        setNeedsDisplay()
    }

    private func respawnIfNeeded() {
        let count = reduceMotion ? min(40, dropletCount / 3) : dropletCount
        droplets = (0..<count).map { _ in makeDroplet(spawnTop: false) }
        setNeedsDisplay()
    }

    private func makeDroplet(spawnTop: Bool) -> Droplet {
        let design = designSize
        let x = CGFloat.random(in: -30...(design.width + 30))
        let y = spawnTop
            ? CGFloat.random(in: -80...(-8))
            : CGFloat.random(in: -40...(design.height))
        return Droplet(
            x: x,
            y: y,
            length: CGFloat.random(in: 8...20),
            alpha: CGFloat.random(in: 0.15...0.5),
            // Speeds were authored for ~360pt width; scale with design width.
            speed: CGFloat.random(in: 4.0...6.2) * max(1, design.width / 360)
        )
    }
}

// MARK: - Layer 4: warm lamp

private final class WarmLampGlowView: UIView {
    var centerInView: CGPoint = .zero
    var pointScale: CGFloat = 1
    var baseRadiusDesign: CGFloat = 100
    var intensity: CGFloat = 0.85
    var audioBoost: CGFloat = 0

    private var time: CGFloat = 0
    private var radius: CGFloat = 100
    /// 0…~1.8 — values above 1 drive an overbright core (screen-stacked).
    private var alphaValue: CGFloat = 0.7

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.clear(rect)

        let r = max(radius, 8) * pointScale
        guard r > 1 else { return }

        let a = min(1.0, alphaValue)
        let overbright = max(0, alphaValue - 1.0) // 0…~0.8

        let colors = [
            UIColor(red: 1, green: 1, blue: 0.88, alpha: min(1, a * 1.15)).cgColor,
            UIColor(red: 1, green: 200 / 255, blue: 90 / 255, alpha: a * 0.95).cgColor,
            UIColor(red: 1, green: 130 / 255, blue: 40 / 255, alpha: a * 0.5).cgColor,
            UIColor(red: 0, green: 0, blue: 0, alpha: 0).cgColor
        ] as CFArray
        let locations: [CGFloat] = [0, 0.22, 0.6, 1]
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) else {
            return
        }

        ctx.saveGState()
        ctx.setBlendMode(.screen)
        ctx.drawRadialGradient(
            gradient,
            startCenter: centerInView,
            startRadius: 0,
            endCenter: centerInView,
            endRadius: r,
            options: [.drawsAfterEndLocation]
        )

        // Extra hot core on peaks — stacks under screen for a brighter max.
        if overbright > 0.02 {
            let coreColors = [
                UIColor(red: 1, green: 1, blue: 0.95, alpha: min(1, 0.55 + overbright)).cgColor,
                UIColor(red: 1, green: 220 / 255, blue: 140 / 255, alpha: overbright * 0.85).cgColor,
                UIColor(red: 0, green: 0, blue: 0, alpha: 0).cgColor
            ] as CFArray
            let coreLocs: [CGFloat] = [0, 0.35, 1]
            if let core = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: coreColors, locations: coreLocs) {
                ctx.drawRadialGradient(
                    core,
                    startCenter: centerInView,
                    startRadius: 0,
                    endCenter: centerInView,
                    endRadius: r * (0.45 + overbright * 0.2),
                    options: [.drawsAfterEndLocation]
                )
            }
        }
        ctx.restoreGState()
    }

    func tick(delta: CGFloat) {
        if delta > 0 {
            time += 0.01 * (delta / (1.0 / 60.0))
        }
        // Extreme lamp surge: deep breath + harsh per-frame flicker + wild radius.
        let surge = sin(time * 2.4) * 0.55 + sin(time * 5.1) * 0.28
        let baseAlpha = 0.75 + surge
        let flicker = CGFloat.random(in: -0.28...0.35)
        // Allow >1 so draw() can stack an overbright core at the peaks.
        alphaValue = max(0.08, min(1.85, baseAlpha + flicker + audioBoost)) * max(intensity, 0.9)
        radius = baseRadiusDesign
            + sin(time * 2.1) * 36.0
            + sin(time * 4.7) * 14.0
            + CGFloat.random(in: -18...18)
        setNeedsDisplay()
    }
}
