import SwiftUI
import UIKit

struct SpatialCanvasView: View {
    @ObservedObject var viewModel: SpatialTimelineViewModel

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let fieldRadius = max(side / 2 - 42, 1)

            ZStack {
                soundFieldBackground(side: side)

                if let selected = viewModel.selectedSource,
                   selected.keyPoints.count >= 2,
                   !viewModel.isPlaying {
                    SpatialPathView(
                        source: selected,
                        currentTime: viewModel.currentTime,
                        fieldRadius: fieldRadius
                    )
                    .frame(width: side, height: side)
                    .transition(.opacity)
                }

                listenerNode
                    .position(x: side / 2, y: side / 2)

                ForEach(viewModel.soundSources) { source in
                    SoundSourceNodeView(
                        source: source,
                        position: viewModel.position(for: source),
                        isSelected: viewModel.selectedSourceID == source.id,
                        isPlaying: viewModel.isPlaying,
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
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: 0x14233A).opacity(0.92),
                            Color(hex: 0x0B1321).opacity(0.96),
                            Color(hex: 0x060A12)
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: side * 0.52
                    )
                )

            ForEach([0.28, 0.50, 0.72, 0.92], id: \.self) { fraction in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                DreamTheme.warmApricot.opacity(0.26),
                                DreamTheme.mistBlue.opacity(0.12),
                                Color.white.opacity(0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: fraction == 0.92 ? 1.1 : 0.7
                    )
                    .frame(width: side * fraction, height: side * fraction)
            }

            Circle()
                .stroke(
                    DreamTheme.warmApricot.opacity(0.22),
                    style: StrokeStyle(lineWidth: 0.8, dash: [2, 8])
                )
                .frame(width: side * 0.98, height: side * 0.98)

            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            DreamTheme.mistBlue.opacity(0.12),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: side * 0.40
                    )
                )
                .frame(width: side * 0.92, height: side * 0.48)
                .blur(radius: 18)
        }
        .frame(width: side, height: side)
    }

    private var listenerNode: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.32))
                .frame(width: 52, height: 52)
            Circle()
                .stroke(DreamTheme.warmApricot.opacity(0.42), lineWidth: 1)
                .frame(width: 52, height: 52)
            Image(systemName: "person.fill")
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(DreamTheme.moonWhite.opacity(0.92))
                .shadow(color: DreamTheme.warmApricot.opacity(0.40), radius: 8)
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
    let side: CGFloat
    let fieldRadius: CGFloat
    @ObservedObject var viewModel: SpatialTimelineViewModel

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
                        source.themeColor.opacity(isSelected ? 0.95 : 0.58),
                        lineWidth: isSelected ? 1.5 : 1
                    )
                Image(systemName: source.iconName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(source.themeColor)
            }
            .frame(width: 48, height: 48)
            .scaleEffect(isSelected || isDragging ? 1.08 : 1)
            .shadow(
                color: source.themeColor.opacity(isSelected || isDragging ? 0.55 : 0.20),
                radius: isSelected || isDragging ? 12 : 5
            )

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
                let normalized = SpatialCanvasTransform.normalizedPoint(
                    from: value.location,
                    side: side,
                    fieldRadius: fieldRadius,
                    clampToField: false
                )
                edgeHaptics.update(for: hypot(normalized.x, normalized.y))
                viewModel.updateSourceDrag(source.id, position: normalized)
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
        .accessibilityHint("拖动记录位置；拖出圆盘可移除音源")
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
    private let generator = UIImpactFeedbackGenerator(style: .soft)
    private var lastImpactTime: TimeInterval = 0
    private var isInEdgeZone = false

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

        generator.impactOccurred(intensity: 0.25 + (0.75 * proximity))
        generator.prepare()
        lastImpactTime = now
        isInEdgeZone = true
    }

    func stop() {
        isInEdgeZone = false
        lastImpactTime = 0
    }
}

private struct SpatialPathView: View {
    let source: SpatialEditorSource
    let currentTime: Double
    let fieldRadius: CGFloat

    var body: some View {
        Canvas { context, size in
            let sorted = source.keyPoints.sorted { $0.time < $1.time }
            guard sorted.count >= 2 else { return }

            var path = Path()
            var hasMoved = false
            for segmentIndex in 0..<(sorted.count - 1) {
                let start = sorted[segmentIndex]
                let end = sorted[segmentIndex + 1]
                let samples = 18
                for sampleIndex in 0...samples {
                    let progress = Double(sampleIndex) / Double(samples)
                    let sampleTime = start.time + (end.time - start.time) * progress
                    let normalized = SpatialTrajectory.position(
                        at: sampleTime,
                        keyPoints: sorted,
                        defaultPosition: source.defaultPosition
                    )
                    let point = SpatialCanvasTransform.canvasPoint(
                        from: normalized,
                        side: min(size.width, size.height),
                        fieldRadius: fieldRadius
                    )
                    if hasMoved {
                        path.addLine(to: point)
                    } else {
                        path.move(to: point)
                        hasMoved = true
                    }
                }
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

            let neighbors = SpatialTrajectory.neighboringPoints(
                at: currentTime,
                keyPoints: sorted
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
}
