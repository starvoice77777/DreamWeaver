import Combine
import SwiftUI

/// Infinite 3D cylindrical spiral ported from the supplied HTML reference.
///
/// Cards rotate around the Y axis while advancing linearly on Y, so every full
/// revolution becomes the next turn of a helix. Repeated virtual cards keep the
/// structure populated above and below the viewport.
struct SpiralSceneCarousel: View {
    @EnvironmentObject private var appState: AppState

    let scenes: [DreamScene]
    var onActivate: (DreamScene) -> Void

    @State private var renderedRotation: CGFloat = 0
    @State private var targetRotation: CGFloat = 0
    @State private var angularVelocity: CGFloat = 0
    @State private var isDragging = false
    @State private var previousDragX: CGFloat = 0
    @State private var lastFrameDate: Date?

    private let replicaCount = 3
    private let maximumVisibleCardsPerSide = 13
    private let angleStep: CGFloat = 24
    private let dragSensitivity: CGFloat = 0.4
    private let autoSpinDegreesPerFrame: CGFloat = 0.05
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
                spiralStage(in: proxy.size)
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
    private func spiralStage(in size: CGSize) -> some View {
        let virtualCount = max(scenes.count * replicaCount, 30)
        let range = CGFloat(virtualCount) * angleStep
        // The front perspective scale is 1.30, so a 46%-wide base card
        // projects to roughly 60% of the viewport: one complete main card plus
        // about one-third of each neighboring card remains visible at the sides.
        let cardWidth = size.width * 0.46
        // Give the enlarged cards a longer vertical silhouette while retaining
        // enough landscape width for the scene artwork and labels.
        let cardHeight = cardWidth * 0.86
        let radius = size.width * 1.05
        // HTML uses 35 px for a 260 px card. The app card is landscape and
        // shorter, so 30 pt preserves the video's open vertical spiral.
        let heightStep: CGFloat = 42
        let placements = visiblePlacements(
            virtualCount: virtualCount,
            range: range,
            heightStep: heightStep
        )

        ZStack {
            ForEach(placements) { placement in
                spiralCard(
                    scene: scenes[placement.virtualIndex % scenes.count],
                    normalizedAngle: placement.angle,
                    yOffset: placement.yOffset,
                    radius: radius,
                    cardWidth: cardWidth,
                    cardHeight: cardHeight,
                    containerSize: size
                )
            }
        }
        // Matches the reference stage's rotateX(8deg) rotateZ(-2deg).
        .rotation3DEffect(
            .degrees(8),
            axis: (x: 1, y: 0, z: 0),
            perspective: 0.08
        )
        .rotationEffect(.degrees(-2))
    }

    @ViewBuilder
    private func spiralCard(
        scene: DreamScene,
        normalizedAngle: CGFloat,
        yOffset: CGFloat,
        radius: CGFloat,
        cardWidth: CGFloat,
        cardHeight: CGFloat,
        containerSize: CGSize
    ) -> some View {
        let radians = normalizedAngle * .pi / 180
        let zPosition = cos(radians) * radius
        let depthRatio = min(max((zPosition + radius) / (2 * radius), 0), 1)
        let xPosition = sin(radians) * radius

        // CSS perspective naturally enlarges the front and shrinks the back.
        // This bounded equivalent keeps the iOS layout stable on small screens.
        let perspectiveScale = 0.58 + 0.72 * depthRatio
        // CSS perspective scales both the card and its translated position.
        // Applying the same ratio here keeps background spacing visually equal
        // to the front instead of leaving small cards on an oversized radius.
        let positionScale = perspectiveScale / 1.30
        let projectedX = xPosition * positionScale
        let projectedY = yOffset * positionScale
        let projectedHalfWidth = cardWidth * perspectiveScale / 2
        let projectedHalfHeight = cardHeight * perspectiveScale / 2
        let horizontalExit = max(
            abs(projectedX) + projectedHalfWidth - containerSize.width / 2,
            0
        ) / max(projectedHalfWidth * 1.15, 1)
        let verticalExit = max(
            abs(projectedY) + projectedHalfHeight - containerSize.height / 2,
            0
        ) / max(projectedHalfHeight * 1.15, 1)
        // Stay fully visible until the card first touches an edge, then fade
        // continuously while the existing cylindrical trajectory carries it out.
        let edgeFade = 1 - min(max(horizontalExit, verticalExit), 1)
        // Keep the back turn legible as a silhouette without restoring its
        // expensive motif/text layers.
        let opacity = 0.28 + 0.72 * Double(depthRatio)
        let darkness = 0.44 * (1 - Double(depthRatio))
        let isFocused = abs(normalizedAngle) < angleStep * 0.52
        // The visible window is capped at 19 cards, so every foreground and
        // background card can keep its complete artwork and labels.
        let showsMotif = true
        let showsDetails = true

        SpiralSceneCard(
            scene: scene,
            isFocused: isFocused,
            isPlaying: appState.isPlaying && appState.currentSceneId == scene.id,
            darkness: darkness,
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
        // Back faces remain visible, matching backface-visibility: visible.
        .rotation3DEffect(
            .degrees(Double(normalizedAngle)),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.42
        )
        .offset(
            x: projectedX,
            y: projectedY
        )
        .zIndex(Double(zPosition))
        .allowsHitTesting(!isDragging && edgeFade > 0.45)
        .accessibilityAddTraits(isFocused ? .isSelected : [])
    }

    private func visiblePlacements(
        virtualCount: Int,
        range: CGFloat,
        heightStep: CGFloat
    ) -> [SpiralPlacement] {
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
            return SpiralPlacement(
                virtualIndex: virtualIndex,
                angle: angle,
                yOffset: angle / angleStep * heightStep
            )
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    previousDragX = value.translation.width
                    angularVelocity = 0
                    return
                }

                let deltaX = value.translation.width - previousDragX
                let deltaRotation = deltaX * dragSensitivity
                targetRotation += deltaRotation
                angularVelocity = deltaRotation
                previousDragX = value.translation.width
            }
            .onEnded { _ in
                isDragging = false
                previousDragX = 0
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

private struct SpiralPlacement: Identifiable {
    let virtualIndex: Int
    let angle: CGFloat
    let yOffset: CGFloat

    var id: Int { virtualIndex }
}

private struct SpiralSceneCard: View {
    let scene: DreamScene
    let isFocused: Bool
    let isPlaying: Bool
    let darkness: Double
    let showsMotif: Bool
    let showsDetails: Bool
    var onTap: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(scene.palette.gradient)
                .overlay {
                    if showsMotif {
                        SceneMiniMotif(style: scene.visualStyle)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
                .overlay {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.58)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

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
        .onTapGesture(perform: onTap)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08 + (isFocused ? 0.10 : 0)), lineWidth: 1)
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
}

#Preview {
    SpiralSceneCarousel(
        scenes: MockDataService.makeScenes(),
        onActivate: { _ in }
    )
    .background(Color.black)
    .environmentObject(AppState())
}
