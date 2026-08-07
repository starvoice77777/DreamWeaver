import SwiftUI
import UIKit

struct SpatialCanvasView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @ObservedObject var viewModel: SpatialTimelineViewModel
    @Environment(\.sceneAdaptiveAccent) private var sceneAccent

    private var reduceMotion: Bool {
        appState.reduceMotion || systemReduceMotion
    }

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let fieldRadius = max(side / 2 - 42, 1)

            ZStack {
                soundFieldBackground(side: side)

                if let selected = viewModel.selectedSource,
                   viewModel.hasTrajectory(for: selected),
                   !viewModel.isPlaying || viewModel.isRecordingTrajectory {
                    SpatialPathView(
                        source: selected,
                        currentTime: viewModel.currentTime,
                        fieldRadius: fieldRadius,
                        liveSamples: viewModel.recordingTrajectorySourceID == selected.id
                            ? viewModel.liveRecordingSamples
                            : []
                    )
                    .frame(width: side, height: side)
                    .transition(.opacity)
                }

                listenerNode
                    .position(x: side / 2, y: side / 2)

                ForEach(viewModel.visibleSoundSources) { source in
                    SoundSourceNodeView(
                        source: source,
                        position: viewModel.position(for: source),
                        isSelected: viewModel.selectedSourceID == source.id,
                        isPlaying: viewModel.isPlaying,
                        isRecording: viewModel.recordingTrajectorySourceID == source.id,
                        side: side,
                        fieldRadius: fieldRadius,
                        viewModel: viewModel
                    )
                }
            }
            .frame(width: side, height: side)
            .coordinateSpace(name: SpatialCanvasTransform.coordinateSpace)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func soundFieldBackground(side: CGFloat) -> some View {
        BreathingSpatialRings(
            accent: sceneAccent,
            reduceMotion: reduceMotion
        )
        .frame(width: side, height: side)
    }

    private var listenerNode: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.32))
                .frame(width: 52, height: 52)
            Circle()
                .stroke(sceneAccent.opacity(0.42), lineWidth: 1)
                .frame(width: 52, height: 52)
            DreamWeaverListenerMark(
                accent: sceneAccent,
                lineWidth: 2.2
            )
            .frame(width: 18, height: 31)
        }
        .allowsHitTesting(false)
        .accessibilityLabel("聆听位置")
    }
}

private struct SoundSourceNodeView: View {
    let source: SpatialEditorSource
    let position: CGPoint
    let isSelected: Bool
    let isPlaying: Bool
    let isRecording: Bool
    let side: CGFloat
    let fieldRadius: CGFloat
    @ObservedObject var viewModel: SpatialTimelineViewModel
    @Environment(\.sceneAdaptiveAccent) private var sceneAccent

    @State private var isDragging = false
    @State private var edgeHaptics = EdgeProximityHaptics()

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.34))
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                source.themeColor.opacity(isSelected ? 0.30 : 0.18),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 2,
                            endRadius: 27
                        )
                    )
                Circle()
                    .stroke(
                        isRecording
                            ? sceneAccent
                            : source.themeColor.opacity(isSelected ? 0.95 : 0.58),
                        lineWidth: isRecording ? 2.2 : (isSelected ? 1.5 : 1)
                    )
                Image(systemName: source.iconName)
                    .font(.system(size: DreamIconSize.content, weight: .medium))
                    .foregroundStyle(source.themeColor)
            }
            .frame(width: 48, height: 48)
            .scaleEffect(isSelected || isDragging ? 1.08 : 1)
            .shadow(
                color: (isRecording ? sceneAccent : source.themeColor)
                    .opacity(isSelected || isDragging ? 0.55 : 0.20),
                radius: isSelected || isDragging || isRecording ? 12 : 5
            )

            if isRecording {
                Circle()
                    .fill(Color.red.opacity(0.92))
                    .frame(width: 6, height: 6)
                    .shadow(color: Color.red.opacity(0.55), radius: 4)
            }

            Text(source.name)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DreamTheme.moonWhite.opacity(0.88))
                .lineLimit(1)

            Text(distanceText)
                .font(.system(size: 9))
                .foregroundStyle(source.themeColor.opacity(0.72))
        }
        .frame(width: 88, height: 78)
        .contentShape(Rectangle())
        .position(
            SpatialCanvasTransform.canvasPoint(
                from: position,
                side: side,
                fieldRadius: fieldRadius
            )
        )
        .background {
            EdgeHapticAttachmentView(haptics: edgeHaptics)
                .allowsHitTesting(false)
        }
        .onTapGesture {
            viewModel.selectSource(source.id)
        }
        .highPriorityGesture(
            DragGesture(
                minimumDistance: 3,
                coordinateSpace: .named(SpatialCanvasTransform.coordinateSpace)
            )
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    viewModel.beginSourceDrag(source.id)
                }
                let rawPosition = SpatialCanvasTransform.normalizedPoint(
                    from: value.location,
                    side: side,
                    fieldRadius: fieldRadius,
                    clampToField: false
                )
                edgeHaptics.update(for: hypot(rawPosition.x, rawPosition.y))
                viewModel.updateSourceDrag(
                    source.id,
                    position: SpatialCanvasTransform.rubberBandedPoint(rawPosition)
                )
            }
            .onEnded { value in
                let normalized = SpatialCanvasTransform.normalizedPoint(
                    from: value.location,
                    side: side,
                    fieldRadius: fieldRadius,
                    clampToField: false
                )
                edgeHaptics.stop()
                viewModel.endSourceDrag(source.id, position: normalized)
                isDragging = false
            }
        )
        .opacity(isOutsideField ? 0.55 : 1)
        .animation(.easeInOut(duration: 0.24), value: isSelected)
        .accessibilityLabel("\(source.name)，\(distanceText)")
        .accessibilityHint(
            isRecording
                ? "正在实时记录拖动轨迹"
                : "拖动记录位置；拖出圆盘可移除音源"
        )
    }

    private var isOutsideField: Bool {
        isDragging && hypot(position.x, position.y) > 1.02
    }

    private var distanceText: String {
        let radius = hypot(position.x, position.y)
        if radius < 0.34 { return "近" }
        if radius < 0.68 { return "中" }
        return "远"
    }
}

@MainActor
private final class EdgeProximityHaptics {
    private let activationDistance: CGFloat = 0.78
    private let edgeDistance: CGFloat = 1.0
    private weak var attachedView: UIView?
    private var generator: UIImpactFeedbackGenerator?
    private var lastImpactTime: TimeInterval = 0
    private var isInEdgeZone = false

    func attach(to view: UIView) {
        guard attachedView !== view else { return }
        attachedView = view
        generator = UIImpactFeedbackGenerator(style: .soft, view: view)
        generator?.prepare()
    }

    func update(for distance: CGFloat) {
        guard distance >= activationDistance else {
            isInEdgeZone = false
            return
        }

        let proximity = min(
            max((distance - activationDistance) / (edgeDistance - activationDistance), 0),
            1
        )
        let now = ProcessInfo.processInfo.systemUptime
        let interval = 0.16 - (0.10 * proximity)

        guard !isInEdgeZone || now - lastImpactTime >= interval else { return }

        generator?.impactOccurred(intensity: 0.25 + (0.75 * proximity))
        generator?.prepare()
        lastImpactTime = now
        isInEdgeZone = true
    }

    func stop() {
        isInEdgeZone = false
        lastImpactTime = 0
    }
}

private struct EdgeHapticAttachmentView: UIViewRepresentable {
    let haptics: EdgeProximityHaptics

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        haptics.attach(to: view)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        haptics.attach(to: view)
    }
}

private struct SpatialPathView: View {
    let source: SpatialEditorSource
    let currentTime: Double
    let fieldRadius: CGFloat
    let liveSamples: [SpatialMotionSample]
    @Environment(\.sceneAdaptiveAccent) private var sceneAccent

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let trajectory = sampledTrajectory
            if trajectory.count >= 2 {
                var path = Path()
                for (index, normalized) in trajectory.enumerated() {
                    let point = SpatialCanvasTransform.canvasPoint(
                        from: normalized,
                        side: side,
                        fieldRadius: fieldRadius
                    )
                    index == 0 ? path.move(to: point) : path.addLine(to: point)
                }
                context.stroke(
                    path,
                    with: .color(source.themeColor.opacity(0.32)),
                    style: StrokeStyle(
                        lineWidth: 1.4,
                        lineCap: .round,
                        lineJoin: .round,
                        dash: [5, 7]
                    )
                )
            }

            if liveSamples.count >= 2 {
                var livePath = Path()
                for (index, sample) in liveSamples.enumerated() {
                    let point = SpatialCanvasTransform.canvasPoint(
                        from: sample.position,
                        side: side,
                        fieldRadius: fieldRadius
                    )
                    index == 0 ? livePath.move(to: point) : livePath.addLine(to: point)
                }
                context.stroke(
                    livePath,
                    with: .color(sceneAccent.opacity(0.92)),
                    style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round)
                )
            }

            let neighbors = SpatialTrajectory.neighboringPoints(
                at: currentTime,
                keyPoints: source.keyPoints
            )
            for point in [neighbors.previous, neighbors.next].compactMap({ $0 }) {
                let canvasPoint = SpatialCanvasTransform.canvasPoint(
                    from: point.position,
                    side: min(size.width, size.height),
                    fieldRadius: fieldRadius
                )
                let marker = Path(
                    ellipseIn: CGRect(
                        x: canvasPoint.x - 4,
                        y: canvasPoint.y - 4,
                        width: 8,
                        height: 8
                    )
                )
                context.fill(
                    marker,
                    with: .color(source.themeColor.opacity(0.48))
                )
            }
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private var sampledTrajectory: [CGPoint] {
        let anchors = SpatialTrajectory.flattenedKeyPoints(for: source)
        guard anchors.count >= 2 else { return anchors.map(\.position) }

        var result: [CGPoint] = []
        for index in 0..<(anchors.count - 1) {
            let start = anchors[index]
            let end = anchors[index + 1]
            let count = min(max(Int(ceil((end.time - start.time) / 0.25)), 1), 18)
            for sampleIndex in 0..<count {
                let progress = Double(sampleIndex) / Double(count)
                let time = start.time + (end.time - start.time) * progress
                result.append(SpatialTrajectory.position(at: time, source: source))
            }
        }
        if let endTime = anchors.last?.time {
            result.append(SpatialTrajectory.position(at: endTime, source: source))
        }
        return result
    }
}

enum SpatialCanvasTransform {
    static let coordinateSpace = "spatialEditorCanvas"

    static func canvasPoint(
        from normalized: CGPoint,
        side: CGFloat,
        fieldRadius: CGFloat
    ) -> CGPoint {
        CGPoint(
            x: side / 2 + normalized.x * fieldRadius,
            y: side / 2 + normalized.y * fieldRadius
        )
    }

    static func normalizedPoint(
        from canvasPoint: CGPoint,
        side: CGFloat,
        fieldRadius: CGFloat,
        clampToField: Bool = true
    ) -> CGPoint {
        let point = CGPoint(
            x: (canvasPoint.x - side / 2) / max(fieldRadius, 1),
            y: (canvasPoint.y - side / 2) / max(fieldRadius, 1)
        )
        return clampToField ? SpatialTrajectory.clampedToUnitCircle(point) : point
    }

    /// Compresses overshoot beyond the field so removing a source requires a
    /// deliberate pull instead of a few accidental points past the rim.
    static func rubberBandedPoint(_ point: CGPoint) -> CGPoint {
        let radius = hypot(point.x, point.y)
        guard radius > 1 else { return point }

        let overshoot = radius - 1
        let resistanceLength: CGFloat = 0.28
        let resistedOvershoot = overshoot * resistanceLength / (overshoot + resistanceLength)
        let scale = (1 + resistedOvershoot) / radius
        return CGPoint(x: point.x * scale, y: point.y * scale)
    }
}
