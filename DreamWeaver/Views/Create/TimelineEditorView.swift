import SwiftUI

struct TimelineEditorView: View {
    @ObservedObject var viewModel: SpatialTimelineViewModel
    @Environment(\.sceneAdaptiveAccent) private var sceneAccent

    private let labelWidth: CGFloat = 104
    private let rulerHeight: CGFloat = 34
    private let trackHeight: CGFloat = 58

    private var totalHeight: CGFloat {
        rulerHeight + CGFloat(viewModel.soundSources.count) * trackHeight
    }

    var body: some View {
        GeometryReader { proxy in
            let timelineWidth = max(proxy.size.width - labelWidth - 12, 1)

            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Color.clear
                            .frame(width: labelWidth, alignment: .leading)

                        TimelineRulerView(
                            duration: viewModel.duration,
                            currentTime: viewModel.currentTime,
                            onScrub: viewModel.scrub
                        )
                        .frame(width: timelineWidth, height: rulerHeight)
                    }
                    .frame(height: rulerHeight)

                    ForEach(viewModel.soundSources) { source in
                        TimelineTrackView(
                            source: source,
                            editMode: viewModel.timelineEditMode,
                            currentTime: viewModel.currentTime,
                            duration: viewModel.duration,
                            timelineWidth: timelineWidth,
                            labelWidth: labelWidth,
                            trackHeight: trackHeight,
                            isSelectedSource: viewModel.selectedSourceID == source.id,
                            selectedKeyPointID: viewModel.selectedKeyPointID,
                            viewModel: viewModel
                        )
                    }
                }

                TimelinePlayheadView(
                    currentTime: viewModel.currentTime,
                    duration: viewModel.duration,
                    timelineWidth: timelineWidth,
                    height: totalHeight,
                    onScrub: viewModel.scrub
                )
                .offset(x: labelWidth + 12)
                .allowsHitTesting(true)
            }
        }
        .frame(height: totalHeight)
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.30))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(sceneAccent.opacity(0.22), lineWidth: 0.8)
                }
        }
    }
}

private struct TimelineRulerView: View {
    let duration: Double
    let currentTime: Double
    let onScrub: (Double) -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                ForEach(0...8, id: \.self) { index in
                    let fraction = CGFloat(index) / 8
                    let seconds = duration * Double(fraction)
                    Rectangle()
                        .fill(Color.white.opacity(index.isMultiple(of: 2) ? 0.28 : 0.14))
                        .frame(width: 0.7, height: index.isMultiple(of: 2) ? 8 : 4)
                        .offset(x: fraction * proxy.size.width)

                    if index.isMultiple(of: 2) {
                        Text(SpatialTimeText.string(seconds))
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(DreamTheme.tertiaryText)
                            .offset(
                                x: min(max(fraction * proxy.size.width - 12, 0), proxy.size.width - 24),
                                y: 10
                            )
                    }
                }

                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                onScrub(
                                    duration
                                        * Double(min(max(value.location.x / proxy.size.width, 0), 1))
                                )
                            }
                    )
            }
        }
        .accessibilityLabel("时间指针")
        .accessibilityValue(SpatialTimeText.string(currentTime))
        .accessibilityHint("左右拖动调整当前时间")
    }
}

private struct TimelineTrackView: View {
    let source: SpatialEditorSource
    let editMode: SpatialTimelineEditMode
    let currentTime: Double
    let duration: Double
    let timelineWidth: CGFloat
    let labelWidth: CGFloat
    let trackHeight: CGFloat
    let isSelectedSource: Bool
    let selectedKeyPointID: UUID?
    @ObservedObject var viewModel: SpatialTimelineViewModel

    var body: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.selectSource(source.id)
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: source.iconName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(source.themeColor)
                        .frame(width: 24, height: 24)
                        .background {
                            Circle().fill(source.themeColor.opacity(0.12))
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(source.name)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(DreamTheme.moonWhite.opacity(0.88))
                            .lineLimit(1)
                        Text(trackSubtitle)
                            .font(.system(size: 8))
                            .foregroundStyle(DreamTheme.tertiaryText)
                    }
                }
                .frame(width: labelWidth, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.045))
                    .frame(height: 18)

                if editMode == .audioTiming {
                    AudioClipRangeView(
                        source: source,
                        duration: duration,
                        trackWidth: timelineWidth,
                        viewModel: viewModel
                    )
                } else {
                    AudioClipContextView(
                        source: source,
                        currentTime: currentTime,
                        duration: duration,
                        trackWidth: timelineWidth
                    )

                    TimelineMotionClipRangesView(
                        clips: source.motionClips ?? [],
                        liveSamples: viewModel.recordingTrajectorySourceID == source.id
                            ? viewModel.liveRecordingSamples
                            : [],
                        duration: duration,
                        color: source.themeColor
                    )

                    TimelinePointConnectionView(
                        keyPoints: source.keyPoints,
                        duration: duration,
                        color: source.themeColor
                    )

                    ForEach(source.keyPoints) { point in
                        SpatialKeyPointView(
                            sourceID: source.id,
                            point: point,
                            duration: duration,
                            trackWidth: timelineWidth,
                            isSelected: selectedKeyPointID == point.id,
                            sourceColor: source.themeColor,
                            viewModel: viewModel
                        )
                    }
                }
            }
            .frame(width: timelineWidth, height: trackHeight)
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.selectSource(source.id)
            }
        }
        .frame(height: trackHeight)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    isSelectedSource
                        ? source.themeColor.opacity(0.055)
                        : Color.clear
                )
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.045))
                .frame(height: 0.6)
        }
    }

    private var trackSubtitle: String {
        switch editMode {
        case .audioTiming:
            return "\(SpatialTimeText.string(source.audioStartTime))"
                + "–\(SpatialTimeText.string(source.audioEndTime))"
        case .spatialTrajectory:
            let clipCount = (source.motionClips ?? []).count
            if clipCount > 0 {
                return "\(source.keyPoints.count) 个定位点 · \(clipCount) 段录制"
            }
            return "\(source.keyPoints.count) 个定位点"
        }
    }
}

private struct TimelineMotionClipRangesView: View {
    let clips: [SpatialMotionClip]
    let liveSamples: [SpatialMotionSample]
    let duration: Double
    let color: Color
    @Environment(\.sceneAdaptiveAccent) private var sceneAccent

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                ForEach(clips) { clip in
                    clipRange(
                        start: clip.startTime,
                        end: clip.endTime,
                        width: proxy.size.width,
                        fill: color.opacity(0.34)
                    )
                }

                if let first = liveSamples.first, let last = liveSamples.last {
                    clipRange(
                        start: first.time,
                        end: max(last.time, first.time + 0.05),
                        width: proxy.size.width,
                        fill: sceneAccent.opacity(0.88)
                    )
                    .shadow(color: sceneAccent.opacity(0.55), radius: 4)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func clipRange(
        start: Double,
        end: Double,
        width: CGFloat,
        fill: Color
    ) -> some View {
        let startX = CGFloat(min(max(start / duration, 0), 1)) * width
        let endX = CGFloat(min(max(end / duration, 0), 1)) * width
        return Capsule(style: .continuous)
            .fill(fill)
            .frame(width: max(endX - startX, 3), height: 8)
            .offset(x: startX, y: 25)
    }
}

private struct AudioClipContextView: View {
    let source: SpatialEditorSource
    let currentTime: Double
    let duration: Double
    let trackWidth: CGFloat

    var body: some View {
        let startX = CGFloat(source.audioStartTime / duration) * trackWidth
        let endX = CGFloat(source.audioEndTime / duration) * trackWidth
        let clipWidth = max(endX - startX, 2)
        let isCurrentTimeActive =
            currentTime >= source.audioStartTime && currentTime <= source.audioEndTime
        let currentX = CGFloat(currentTime / duration) * trackWidth
        let elapsedWidth = min(max(currentX - startX, 0), clipWidth)

        ZStack(alignment: .topLeading) {
            Capsule()
                .fill(source.themeColor.opacity(isCurrentTimeActive ? 0.13 : 0.065))
                .overlay {
                    Capsule()
                        .stroke(source.themeColor.opacity(0.22), lineWidth: 0.7)
                }
                .frame(width: clipWidth, height: 14)
                .offset(x: startX, y: 22)

            if isCurrentTimeActive {
                Capsule()
                    .fill(source.themeColor.opacity(0.25))
                    .frame(width: max(elapsedWidth, 2), height: 14)
                    .offset(x: startX, y: 22)

                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(source.themeColor.opacity(0.88))
                    .frame(width: 9, height: 20)
                    .shadow(color: source.themeColor.opacity(0.55), radius: 5)
                    .offset(x: currentX - 4.5, y: 19)
            }
        }
        .frame(width: trackWidth, height: 58, alignment: .topLeading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct AudioClipRangeView: View {
    let source: SpatialEditorSource
    let duration: Double
    let trackWidth: CGFloat
    @ObservedObject var viewModel: SpatialTimelineViewModel
    @Environment(\.sceneAdaptiveAccent) private var sceneAccent

    @State private var moveOriginStart: Double?
    @State private var leadingOriginStart: Double?
    @State private var leadingFixedEnd: Double?
    @State private var trailingOriginEnd: Double?
    @State private var trailingFixedStart: Double?

    var body: some View {
        let startX = CGFloat(source.audioStartTime / duration) * trackWidth
        let endX = CGFloat(source.audioEndTime / duration) * trackWidth
        let clipWidth = max(endX - startX, 12)

        ZStack(alignment: .topLeading) {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            source.themeColor.opacity(0.24),
                            source.themeColor.opacity(0.42)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay {
                    Capsule()
                        .stroke(source.themeColor.opacity(0.70), lineWidth: 0.8)
                }
                .overlay {
                    if clipWidth > 52 {
                        Text(SpatialTimeText.string(source.audioDuration))
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundStyle(DreamTheme.moonWhite.opacity(0.76))
                    }
                }
                .frame(width: clipWidth, height: 24)
                .offset(x: startX, y: 17)
                .contentShape(Rectangle())
                .gesture(moveGesture)

            rangeHandle(isLeading: true)
                .position(x: startX, y: 29)
                .highPriorityGesture(leadingResizeGesture)

            rangeHandle(isLeading: false)
                .position(x: endX, y: 29)
                .highPriorityGesture(trailingResizeGesture)
        }
        .frame(width: trackWidth, height: 58, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "\(source.name) 音频，"
                + "\(SpatialTimeText.string(source.audioStartTime))"
                + "到\(SpatialTimeText.string(source.audioEndTime))"
        )
    }

    private func rangeHandle(isLeading: Bool) -> some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.46))
                .frame(width: 20, height: 32)
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(sceneAccent)
                .frame(width: 4, height: 18)
                .shadow(color: sceneAccent.opacity(0.45), radius: 4)
        }
        .frame(width: 24, height: 40)
        .contentShape(Rectangle())
        .accessibilityLabel(isLeading ? "调整音频开始时间" : "调整音频结束时间")
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if moveOriginStart == nil {
                    moveOriginStart = source.audioStartTime
                    viewModel.selectSource(source.id)
                }
                let delta = Double(value.translation.width / max(trackWidth, 1)) * duration
                viewModel.moveAudioClip(
                    sourceID: source.id,
                    proposedStart: (moveOriginStart ?? source.audioStartTime) + delta
                )
            }
            .onEnded { _ in
                moveOriginStart = nil
                viewModel.finishAudioTimingEdit(sourceID: source.id)
            }
    }

    private var leadingResizeGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if leadingOriginStart == nil {
                    leadingOriginStart = source.audioStartTime
                    leadingFixedEnd = source.audioEndTime
                }
                let delta = Double(value.translation.width / max(trackWidth, 1)) * duration
                viewModel.resizeAudioClipStart(
                    sourceID: source.id,
                    proposedStart: (leadingOriginStart ?? source.audioStartTime) + delta,
                    fixedEnd: leadingFixedEnd ?? source.audioEndTime
                )
            }
            .onEnded { _ in
                leadingOriginStart = nil
                leadingFixedEnd = nil
                viewModel.finishAudioTimingEdit(sourceID: source.id)
            }
    }

    private var trailingResizeGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if trailingOriginEnd == nil {
                    trailingOriginEnd = source.audioEndTime
                    trailingFixedStart = source.audioStartTime
                }
                let delta = Double(value.translation.width / max(trackWidth, 1)) * duration
                viewModel.resizeAudioClipEnd(
                    sourceID: source.id,
                    proposedEnd: (trailingOriginEnd ?? source.audioEndTime) + delta,
                    fixedStart: trailingFixedStart ?? source.audioStartTime
                )
            }
            .onEnded { _ in
                trailingOriginEnd = nil
                trailingFixedStart = nil
                viewModel.finishAudioTimingEdit(sourceID: source.id)
            }
    }
}

private struct TimelinePointConnectionView: View {
    let keyPoints: [SpatialKeyPoint]
    let duration: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let points = keyPoints.sorted { $0.time < $1.time }
                guard points.count >= 2 else { return }
                let y = size.height / 2
                var path = Path()
                for (index, point) in points.enumerated() {
                    let x = CGFloat(point.time / duration) * size.width
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                context.stroke(
                    path,
                    with: .color(color.opacity(0.34)),
                    style: StrokeStyle(lineWidth: 1, dash: [3, 4])
                )
            }
        }
        .allowsHitTesting(false)
    }
}

private struct SpatialKeyPointView: View {
    let sourceID: UUID
    let point: SpatialKeyPoint
    let duration: Double
    let trackWidth: CGFloat
    let isSelected: Bool
    let sourceColor: Color
    @ObservedObject var viewModel: SpatialTimelineViewModel
    @Environment(\.sceneAdaptiveAccent) private var sceneAccent

    @State private var dragStartTime: Double?
    @State private var appeared = false

    var body: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(isSelected ? sceneAccent : sourceColor.opacity(0.72))
            .frame(width: isSelected ? 13 : 11, height: isSelected ? 13 : 11)
            .rotationEffect(.degrees(45))
            .overlay {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(Color.white.opacity(isSelected ? 0.78 : 0.20), lineWidth: 0.7)
                    .rotationEffect(.degrees(45))
            }
            .shadow(
                color: sceneAccent.opacity(isSelected ? 0.65 : 0),
                radius: isSelected ? 7 : 0
            )
            .scaleEffect(appeared ? 1 : 0.7)
            .position(
                x: CGFloat(point.time / duration) * trackWidth,
                y: 29
            )
            .contentShape(Rectangle().size(width: 34, height: 34))
            .onAppear {
                withAnimation(.easeOut(duration: 0.24)) {
                    appeared = true
                }
            }
            .onTapGesture {
                viewModel.selectKeyPoint(sourceID: sourceID, keyPointID: point.id)
            }
            .highPriorityGesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        if dragStartTime == nil {
                            dragStartTime = point.time
                            viewModel.selectKeyPoint(
                                sourceID: sourceID,
                                keyPointID: point.id
                            )
                        }
                        let deltaTime =
                            Double(value.translation.width / max(trackWidth, 1)) * duration
                        viewModel.moveKeyPointTime(
                            sourceID: sourceID,
                            keyPointID: point.id,
                            proposedTime: (dragStartTime ?? point.time) + deltaTime
                        )
                    }
                    .onEnded { _ in
                        dragStartTime = nil
                    }
            )
            .contextMenu {
                Button("删除定位点", systemImage: "trash", role: .destructive) {
                    viewModel.deleteKeyPoint(
                        sourceID: sourceID,
                        keyPointID: point.id
                    )
                }
            }
            .accessibilityLabel("定位点 \(SpatialTimeText.string(point.time))")
            .accessibilityHint("点按跳转，左右拖动修改时间，长按删除")
    }
}

private struct TimelinePlayheadView: View {
    let currentTime: Double
    let duration: Double
    let timelineWidth: CGFloat
    let height: CGFloat
    let onScrub: (Double) -> Void
    @Environment(\.sceneAdaptiveAccent) private var sceneAccent

    @State private var dragStartTime: Double?

    var body: some View {
        let x = CGFloat(currentTime / duration) * timelineWidth

        ZStack(alignment: .top) {
            Rectangle()
                .fill(sceneAccent.opacity(0.86))
                .frame(width: 1.2, height: height - 4)

            Diamond()
                .fill(sceneAccent)
                .frame(width: 10, height: 10)
                .shadow(color: sceneAccent.opacity(0.55), radius: 5)
                .offset(y: -2)
                .contentShape(Rectangle().size(width: 34, height: 28))
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if dragStartTime == nil {
                                dragStartTime = currentTime
                            }
                            let delta =
                                Double(value.translation.width / max(timelineWidth, 1)) * duration
                            onScrub((dragStartTime ?? currentTime) + delta)
                        }
                        .onEnded { _ in
                            dragStartTime = nil
                        }
                )
        }
        .frame(width: 1.2, height: height, alignment: .top)
        .offset(x: x)
        .allowsHitTesting(true)
    }
}

private struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}
