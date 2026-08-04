import Combine
import SwiftUI

/// Vertical cylindrical wheel for the scene library.
///
/// Cards travel on a circle in the Y/Z plane and rotate around the X axis,
/// so neighbors stack above and below the focused card like a roller.
/// Virtual replicas keep the wheel populated as it spins infinitely.
struct SpiralSceneCarousel: View {
    @EnvironmentObject private var appState: AppState

    let scenes: [DreamScene]
    var onActivate: (DreamScene) -> Void

    @State private var renderedRotation: CGFloat = 0
    @State private var targetRotation: CGFloat = 0
    @State private var angularVelocity: CGFloat = 0
    @State private var isDragging = false
    @State private var previousDragY: CGFloat = 0
    @State private var lastFrameDate: Date?

    private let replicaCount = 3
    private let maximumVisibleCardsPerSide = 10
    private let angleStep: CGFloat = 28
    private let dragSensitivity: CGFloat = 0.38
    private let autoSpinDegreesPerFrame: CGFloat = 0.12
    private let frictionPerFrame: CGFloat = 0.95
    private let interpolationPerFrame: CGFloat = 0.15

    private let frameTicker = Timer.publish(
        every: 1.0 / 60.0,
        on: .main,
        in: .common
    )
    .autoconnect()

    var body: some View {
        GeometryReader { proxy in
            if scenes.isEmpty {
                ContentUnavailableView(
                    "没有匹配的场景",
                    systemImage: "sparkles",
                    description: Text("尝试选择其他分类或搜索词")
                )
                .foregroundStyle(DreamTheme.secondaryText)
            } else {
                wheelStage(in: proxy.size)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(dragGesture)
                    .clipped()
                    .onReceive(frameTicker, perform: advanceMotion)
                    .onAppear(perform: alignToCurrentScene)
                    .onDisappear {
                        lastFrameDate = nil
                        angularVelocity = 0
                    }
                    .onChange(of: scenes.map(\.id)) { _, _ in
                        alignToCurrentScene()
                    }
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func wheelStage(in size: CGSize) -> some View {
        let virtualCount = max(scenes.count * replicaCount, 30)
        let range = CGFloat(virtualCount) * angleStep
        // Wider main card: neighbors live above/below, so horizontal space can
        // be dedicated to the focused scene artwork.
        let cardWidth = size.width * 0.72
        let cardHeight = cardWidth * 0.62
        // Radius scales with viewport height so the vertical arc stays readable.
        let radius = max(size.height * 0.52, cardHeight * 1.8)
        let placements = visiblePlacements(
            virtualCount: virtualCount,
            range: range
        )

        ZStack {
            ForEach(placements) { placement in
                wheelCard(
                    scene: scenes[placement.virtualIndex % scenes.count],
                    normalizedAngle: placement.angle,
                    radius: radius,
                    cardWidth: cardWidth,
                    cardHeight: cardHeight,
                    containerSize: size
                )
            }
        }
    }

    @ViewBuilder
    private func wheelCard(
        scene: DreamScene,
        normalizedAngle: CGFloat,
        radius: CGFloat,
        cardWidth: CGFloat,
        cardHeight: CGFloat,
        containerSize: CGSize
    ) -> some View {
        let radians = normalizedAngle * .pi / 180
        let zPosition = cos(radians) * radius
        let depthRatio = min(max((zPosition + radius) / (2 * radius), 0), 1)
        // Vertical wheel: travel on Y while depth rides Z.
        let yPosition = sin(radians) * radius

        let perspectiveScale = 0.52 + 0.78 * depthRatio
        let positionScale = perspectiveScale / 1.30
        let projectedY = yPosition * positionScale
        let projectedHalfWidth = cardWidth * perspectiveScale / 2
        let projectedHalfHeight = cardHeight * perspectiveScale / 2
        let horizontalExit = max(
            projectedHalfWidth - containerSize.width / 2,
            0
        ) / max(projectedHalfWidth * 1.15, 1)
        let verticalExit = max(
            abs(projectedY) + projectedHalfHeight - containerSize.height / 2,
            0
        ) / max(projectedHalfHeight * 1.15, 1)
        let edgeFade = 1 - min(max(horizontalExit, verticalExit), 1)
        let opacity = 0.28 + 0.72 * Double(depthRatio)
        let darkness = 0.44 * (1 - Double(depthRatio))
        let isFocused = abs(normalizedAngle) < angleStep * 0.52
        let isBackCard = depthRatio < 0.52
        let showsArt = !isBackCard
        let showsMotif = showsArt
        let showsDetails = showsArt

        SpiralSceneCard(
            scene: scene,
            isFocused: isFocused,
            isPlaying: appState.isPlaying && appState.currentSceneId == scene.id,
            darkness: isBackCard ? 0 : darkness,
            showsArt: showsArt,
            showsMotif: showsMotif,
            showsDetails: showsDetails,
            onTap: {
                if isFocused {
                    onActivate(scene)
                } else {
                    focusCard(angle: normalizedAngle)
                }
            }
        )
        .frame(width: cardWidth, height: cardHeight)
        .scaleEffect(perspectiveScale)
        .opacity(opacity * Double(edgeFade))
        .rotation3DEffect(
            .degrees(Double(-normalizedAngle)),
            axis: (x: 1, y: 0, z: 0),
            perspective: 0.42
        )
        .offset(y: projectedY)
        .zIndex(Double(zPosition))
        .allowsHitTesting(!isDragging && edgeFade > 0.45)
        .accessibilityAddTraits(isFocused ? .isSelected : [])
    }

    private func visiblePlacements(
        virtualCount: Int,
        range: CGFloat
    ) -> [WheelPlacement] {
        guard virtualCount > 0 else { return [] }

        let centerUnwrappedIndex = Int(
            (-renderedRotation / angleStep).rounded()
        )
        let halfWindow = min(
            maximumVisibleCardsPerSide,
            max((virtualCount - 1) / 2, 0)
        )

        return (-halfWindow...halfWindow).map { offset in
            let unwrappedIndex = centerUnwrappedIndex + offset
            let virtualIndex = positiveModulo(unwrappedIndex, virtualCount)
            let rawAngle = CGFloat(virtualIndex) * angleStep + renderedRotation
            let angle = wrappedAngle(rawAngle, range: range)
            return WheelPlacement(
                virtualIndex: virtualIndex,
                angle: angle
            )
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    previousDragY = value.translation.height
                    angularVelocity = 0
                    return
                }

                // Dragging down brings upper cards into focus.
                let deltaY = value.translation.height - previousDragY
                let deltaRotation = deltaY * dragSensitivity
                targetRotation += deltaRotation
                angularVelocity = deltaRotation
                previousDragY = value.translation.height
            }
            .onEnded { _ in
                isDragging = false
                previousDragY = 0
            }
    }

    private func advanceMotion(at date: Date) {
        let elapsed = lastFrameDate.map { date.timeIntervalSince($0) } ?? (1.0 / 60.0)
        lastFrameDate = date
        let frameScale = CGFloat(min(max(elapsed * 60, 0.25), 3))

        if !isDragging {
            targetRotation -= autoSpinDegreesPerFrame * frameScale
            targetRotation += angularVelocity * frameScale
            angularVelocity *= CGFloat(
                pow(Double(frictionPerFrame), Double(frameScale))
            )
            if abs(angularVelocity) < 0.01 {
                angularVelocity = 0
            }
        }

        let interpolation = 1 - CGFloat(
            pow(Double(1 - interpolationPerFrame), Double(frameScale))
        )
        renderedRotation += (targetRotation - renderedRotation) * interpolation

        normalizeLargeRotationsIfNeeded()
    }

    private func focusCard(angle: CGFloat) {
        angularVelocity = 0
        targetRotation -= angle
    }

    private func alignToCurrentScene() {
        guard !scenes.isEmpty else {
            renderedRotation = 0
            targetRotation = 0
            return
        }
        let index = scenes.firstIndex(where: { $0.id == appState.currentSceneId }) ?? 0
        let rotation = -CGFloat(index) * angleStep
        renderedRotation = rotation
        targetRotation = rotation
        angularVelocity = 0
        lastFrameDate = nil
    }

    private func wrappedAngle(_ angle: CGFloat, range: CGFloat) -> CGFloat {
        guard range > 0 else { return 0 }
        let halfRange = range / 2
        var normalized = (angle + halfRange).truncatingRemainder(dividingBy: range)
        if normalized < 0 {
            normalized += range
        }
        return normalized - halfRange
    }

    private func positiveModulo(_ value: Int, _ modulus: Int) -> Int {
        let remainder = value % modulus
        return remainder >= 0 ? remainder : remainder + modulus
    }

    private func normalizeLargeRotationsIfNeeded() {
        let range = CGFloat(max(scenes.count * replicaCount, 1)) * angleStep
        guard range > 0, abs(targetRotation) > range * 4 else { return }
        let normalized = wrappedAngle(targetRotation, range: range)
        let delta = targetRotation - normalized
        targetRotation -= delta
        renderedRotation -= delta
    }
}

private struct WheelPlacement: Identifiable {
    let virtualIndex: Int
    let angle: CGFloat

    var id: Int { virtualIndex }
}

private struct SpiralSceneCard: View {
    let scene: DreamScene
    let isFocused: Bool
    let isPlaying: Bool
    let darkness: Double
    let showsArt: Bool
    let showsMotif: Bool
    let showsDetails: Bool
    var onTap: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(cardFill)
                .overlay {
                    if showsArt {
                        GeometryReader { geo in
                            if let cover = SceneCoverArt.image(for: scene.visualStyle) {
                                Image(uiImage: cover)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: geo.size.width, height: geo.size.height)
                                    .clipped()
                            } else if showsMotif {
                                SceneMiniMotif(style: scene.visualStyle)
                                    .frame(width: geo.size.width, height: geo.size.height)
                            }
                        }
                    }
                }
                .overlay {
                    if showsArt {
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.58)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            if showsDetails {
                VStack(alignment: .leading, spacing: 3) {
                    if isPlaying {
                        Image(systemName: "waveform")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(DreamTheme.warmApricot)
                            .accessibilityLabel("正在播放")
                    }

                    Spacer()

                    Text(scene.name)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(DreamTheme.moonWhite)
                        .lineLimit(1)

                    Text(scene.subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(DreamTheme.moonWhite.opacity(0.72))
                        .lineLimit(1)
                }
                .padding(12)
            }

            Color.black
                .opacity(darkness)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .allowsHitTesting(false)
        }
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture(perform: onTap)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    Color.white.opacity(showsArt ? (0.08 + (isFocused ? 0.10 : 0)) : 0.05),
                    lineWidth: 1
                )
        }
        .shadow(
            color: .black.opacity(isFocused ? 0.60 : 0),
            radius: isFocused ? 15 : 0,
            y: isFocused ? 8 : 0
        )
        .accessibilityHidden(!showsDetails)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(scene.name)，\(scene.subtitle)")
        .accessibilityHint(isFocused ? "轻点进入场景" : "轻点转到此场景")
    }

    private var cardFill: LinearGradient {
        if showsArt {
            return scene.palette.gradient
        }
        // Unified low-saturation gray for back-facing secondary cards.
        return LinearGradient(
            colors: [
                Color(red: 0.20, green: 0.21, blue: 0.23),
                Color(red: 0.14, green: 0.15, blue: 0.17),
                Color(red: 0.10, green: 0.10, blue: 0.12)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

#Preview {
    SpiralSceneCarousel(
        scenes: MockDataService.makeScenes(),
        onActivate: { _ in }
    )
    .background(Color.black)
    .environmentObject(AppState())
}
