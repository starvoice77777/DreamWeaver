import SwiftUI

struct TimelineEditorView: View {
    @ObservedObject var viewModel: SpatialTimelineViewModel
    @Environment(\.sceneAdaptiveAccent) private var sceneAccent

    private let labelWidth: CGFloat = 104
    private let rulerHeight: CGFloat = 34
    private let trackHeight: CGFloat = 66
    private let navigatorHeight: CGFloat = 38

    private var totalHeight: CGFloat {
        rulerHeight + CGFloat(viewModel.sourceGroups.count) * trackHeight + navigatorHeight
    }

    var body: some View {
        GeometryReader { proxy in
            let timelineWidth = max(proxy.size.width - labelWidth - 12, 1)
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Color.clear.frame(width: labelWidth)
                        TimelineRulerView(
                            viewport: viewModel.timelineViewport,
                            currentTime: viewModel.currentTime,
                            onScrub: viewModel.scrub
                        )
                        .frame(width: timelineWidth, height: rulerHeight)
                    }

                    ForEach(viewModel.sourceGroups) { group in
                        TimelineTrackView(
                            group: group,
                            clips: viewModel.clips(for: group.id),
                            generatedAnchors: viewModel.automaticBoundaryKeyPoints(for: group.id),
                            viewport: viewModel.timelineViewport,
                            currentTime: viewModel.currentTime,
                            timelineWidth: timelineWidth,
                            labelWidth: labelWidth,
                            trackHeight: trackHeight,
                            viewModel: viewModel
                        )
                    }

                    TimelineNavigatorView(
                        duration: viewModel.duration,
                        viewport: viewModel.timelineViewport,
                        labelWidth: labelWidth,
                        timelineWidth: timelineWidth,
                        viewModel: viewModel
                    )
                    .frame(height: navigatorHeight)
                }

                if viewModel.currentTime >= viewModel.timelineViewport.startTime,
                   viewModel.currentTime <= viewModel.timelineViewport.endTime {
                    TimelinePlayheadView(
                        currentTime: viewModel.currentTime,
                        viewport: viewModel.timelineViewport,
                        timelineWidth: timelineWidth,
                        height: rulerHeight + CGFloat(viewModel.sourceGroups.count) * trackHeight,
                        onScrub: viewModel.scrub
                    )
                    .offset(x: labelWidth + 12)
                }
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
    let viewport: TimelineViewport
    let currentTime: Double
    let onScrub: (Double) -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                ForEach(0...6, id: \.self) { index in
                    let fraction = CGFloat(index) / 6
                    let seconds = viewport.startTime + viewport.span * Double(fraction)
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
                        DragGesture(minimumDistance: 0).onChanged { value in
                            onScrub(viewport.time(for: value.location.x, width: proxy.size.width))
                        }
                    )
            }
        }
        .accessibilityLabel("时间指针")
        .accessibilityValue(SpatialTimeText.string(currentTime))
    }
}

private struct TimelineTrackView: View {
    let group: SpatialEditorSourceGroup
    let clips: [SpatialEditorAudioClip]
    let generatedAnchors: [SpatialGeneratedBoundaryKeyPoint]
    let viewport: TimelineViewport
    let currentTime: Double
    let timelineWidth: CGFloat
    let labelWidth: CGFloat
    let trackHeight: CGFloat
    @ObservedObject var viewModel: SpatialTimelineViewModel

    private var visibleClips: [SpatialEditorAudioClip] {
        clips.filter { $0.endTime >= viewport.startTime && $0.startTime <= viewport.endTime }
    }

    var body: some View {
        HStack(spacing: 12) {
            Button { viewModel.selectSource(group.id) } label: {
                HStack(spacing: 7) {
                    Image(systemName: group.iconName)
                        .font(.system(size: DreamIconSize.compact, weight: .medium))
                        .foregroundStyle(group.themeColor)
                        .frame(width: 24, height: 24)
                        .background { Circle().fill(group.themeColor.opacity(0.12)) }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.name)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(DreamTheme.moonWhite.opacity(0.88))
                            .lineLimit(1)
                        Text(trackSubtitle)
                            .font(.system(size: 8))
                            .foregroundStyle(DreamTheme.tertiaryText)
                            .lineLimit(1)
                    }
                }
                .frame(width: labelWidth, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(Color.white.opacity(0.045))
                    .frame(height: 18)
                    .offset(y: 28)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.clearTimelineItemSelection()
                        viewModel.selectSource(group.id)
                    }

                if viewModel.timelineEditMode == .audioTiming {
                    ForEach(visibleClips) { clip in
                        AudioClipRangeView(
                            group: group,
                            clip: clip,
                            viewport: viewport,
                            trackWidth: timelineWidth,
                            isSelected: viewModel.selectedAudioClipID == clip.id,
                            viewModel: viewModel
                        )
                    }
                } else {
                    ForEach(visibleClips) { clip in
                        AudioClipContextView(
                            clip: clip,
                            currentTime: currentTime,
                            viewport: viewport,
                            trackWidth: timelineWidth,
                            color: group.themeColor
                        )
                    }
                    TimelineMotionClipRangesView(
                        clips: group.motionClips ?? [],
                        liveSamples: viewModel.recordingTrajectorySourceID == group.id
                            ? viewModel.liveRecordingSamples
                            : [],
                        viewport: viewport,
                        color: group.themeColor
                    )
                    TimelinePointConnectionView(
                        keyPoints: group.keyPoints,
                        generatedAnchors: generatedAnchors,
                        viewport: viewport,
                        color: group.themeColor
                    )
                    ForEach(generatedAnchors.filter { anchor in
                        anchor.time >= viewport.startTime && anchor.time <= viewport.endTime
                            && !group.keyPoints.contains(where: { point in
                                abs(point.time - anchor.time) < 0.001
                            })
                    }) { anchor in
                        GeneratedKeyPointView(
                            point: anchor,
                            viewport: viewport,
                            trackWidth: timelineWidth
                        )
                    }
                    ForEach(group.keyPoints.filter {
                        $0.time >= viewport.startTime && $0.time <= viewport.endTime
                    }) { point in
                        SpatialKeyPointView(
                            sourceID: group.id,
                            point: point,
                            viewport: viewport,
                            trackWidth: timelineWidth,
                            isSelected: viewModel.selectedKeyPointID == point.id,
                            sourceColor: group.themeColor,
                            viewModel: viewModel
                        )
                    }
                }
            }
            .frame(width: timelineWidth, height: trackHeight)
            .clipped()
        }
        .frame(height: trackHeight)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(viewModel.selectedSourceID == group.id ? group.themeColor.opacity(0.055) : .clear)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.045)).frame(height: 0.6)
        }
    }

    private var trackSubtitle: String {
        let total = viewModel.totalActiveDuration(for: group.id)
        return "\(clips.count) 段 · \(SpatialTimeText.string(total))"
    }
}

private struct TimelineMotionClipRangesView: View {
    let clips: [SpatialMotionClip]
    let liveSamples: [SpatialMotionSample]
    let viewport: TimelineViewport
    let color: Color
    @Environment(\.sceneAdaptiveAccent) private var sceneAccent

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                ForEach(clips.filter {
                    $0.endTime >= viewport.startTime && $0.startTime <= viewport.endTime
                }) { clip in
                    range(
                        start: clip.startTime,
                        end: clip.endTime,
                        width: proxy.size.width,
                        fill: color.opacity(0.34)
                    )
                }
                if let first = liveSamples.first, let last = liveSamples.last {
                    range(
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
    }

    private func range(
        start: Double,
        end: Double,
        width: CGFloat,
        fill: Color
    ) -> some View {
        let startX = viewport.x(for: start, width: width)
        let endX = viewport.x(for: end, width: width)
        return Capsule(style: .continuous)
            .fill(fill)
            .frame(width: max(endX - startX, 3), height: 7)
            .offset(x: startX, y: 52)
    }
}

private struct AudioClipRangeView: View {
    let group: SpatialEditorSourceGroup
    let clip: SpatialEditorAudioClip
    let viewport: TimelineViewport
    let trackWidth: CGFloat
    let isSelected: Bool
    @ObservedObject var viewModel: SpatialTimelineViewModel
    @Environment(\.sceneAdaptiveAccent) private var sceneAccent

    @State private var moveOriginStart: Double?
    @State private var leadingOriginStart: Double?
    @State private var leadingFixedEnd: Double?
    @State private var trailingOriginEnd: Double?
    @State private var trailingFixedStart: Double?

    var body: some View {
        let startX = viewport.x(for: clip.startTime, width: trackWidth)
        let endX = viewport.x(for: clip.endTime, width: trackWidth)
        let clipWidth = max(endX - startX, 12)

        ZStack(alignment: .topLeading) {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [group.themeColor.opacity(0.24), group.themeColor.opacity(0.42)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay {
                    Capsule().stroke(
                        isSelected ? sceneAccent : group.themeColor.opacity(0.70),
                        lineWidth: isSelected ? 1.5 : 0.8
                    )
                }
                .overlay {
                    if clipWidth > 52 {
                        Text(SpatialTimeText.string(clip.duration))
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundStyle(DreamTheme.moonWhite.opacity(0.76))
                    }
                }
                .frame(width: clipWidth, height: 24)
                .offset(x: startX, y: 30)
                .contentShape(Rectangle())
                .onTapGesture { viewModel.selectAudioClip(clip.id) }
                .gesture(moveGesture)

            rangeHandle.position(x: startX, y: 42).highPriorityGesture(leadingResizeGesture)
            rangeHandle.position(x: endX, y: 42).highPriorityGesture(trailingResizeGesture)

            if isSelected {
                Button(role: .destructive) { viewModel.deleteAudioClip(clip.id) } label: {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background { Circle().fill(Color.red.opacity(0.78)) }
                }
                .buttonStyle(.plain)
                .position(x: min(max((startX + endX) / 2, 16), trackWidth - 16), y: 13)
                .accessibilityLabel("删除音频段")
            }
        }
        .frame(width: trackWidth, height: 66, alignment: .topLeading)
    }

    private var rangeHandle: some View {
        ZStack {
            Circle().fill(Color.black.opacity(0.46)).frame(width: 20, height: 32)
            RoundedRectangle(cornerRadius: 2).fill(sceneAccent).frame(width: 4, height: 18)
        }
        .frame(width: 24, height: 40)
        .contentShape(Rectangle())
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if moveOriginStart == nil {
                    moveOriginStart = clip.startTime
                    viewModel.selectAudioClip(clip.id)
                }
                let delta = Double(value.translation.width / max(trackWidth, 1)) * viewport.span
                viewModel.moveAudioClip(
                    clipID: clip.id,
                    proposedStart: (moveOriginStart ?? clip.startTime) + delta
                )
            }
            .onEnded { _ in
                moveOriginStart = nil
                viewModel.finishAudioTimingEdit(clipID: clip.id)
            }
    }

    private var leadingResizeGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if leadingOriginStart == nil {
                    leadingOriginStart = clip.startTime
                    leadingFixedEnd = clip.endTime
                    viewModel.selectAudioClip(clip.id)
                }
                let delta = Double(value.translation.width / max(trackWidth, 1)) * viewport.span
                viewModel.resizeAudioClipStart(
                    clipID: clip.id,
                    proposedStart: (leadingOriginStart ?? clip.startTime) + delta,
                    fixedEnd: leadingFixedEnd ?? clip.endTime
                )
            }
            .onEnded { _ in
                leadingOriginStart = nil
                leadingFixedEnd = nil
                viewModel.finishAudioTimingEdit(clipID: clip.id)
            }
    }

    private var trailingResizeGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if trailingOriginEnd == nil {
                    trailingOriginEnd = clip.endTime
                    trailingFixedStart = clip.startTime
                    viewModel.selectAudioClip(clip.id)
                }
                let delta = Double(value.translation.width / max(trackWidth, 1)) * viewport.span
                viewModel.resizeAudioClipEnd(
                    clipID: clip.id,
                    proposedEnd: (trailingOriginEnd ?? clip.endTime) + delta,
                    fixedStart: trailingFixedStart ?? clip.startTime
                )
            }
            .onEnded { _ in
                trailingOriginEnd = nil
                trailingFixedStart = nil
                viewModel.finishAudioTimingEdit(clipID: clip.id)
            }
    }
}

private struct AudioClipContextView: View {
    let clip: SpatialEditorAudioClip
    let currentTime: Double
    let viewport: TimelineViewport
    let trackWidth: CGFloat
    let color: Color

    var body: some View {
        let startX = viewport.x(for: clip.startTime, width: trackWidth)
        let endX = viewport.x(for: clip.endTime, width: trackWidth)
        let active = currentTime >= clip.startTime && currentTime < clip.endTime
        Capsule()
            .fill(color.opacity(active ? 0.20 : 0.08))
            .overlay { Capsule().stroke(color.opacity(0.22), lineWidth: 0.7) }
            .frame(width: max(endX - startX, 2), height: 14)
            .offset(x: startX, y: 34)
            .allowsHitTesting(false)
    }
}

private struct TimelinePointConnectionView: View {
    let keyPoints: [SpatialKeyPoint]
    let generatedAnchors: [SpatialGeneratedBoundaryKeyPoint]
    let viewport: TimelineViewport
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let points = (keyPoints.map(\.time) + generatedAnchors.map(\.time)).sorted()
                let orderedBoundaries = generatedAnchors.sorted { $0.time < $1.time }
                let gaps: [(Double, Double)] = stride(
                    from: 0,
                    to: orderedBoundaries.count - 1,
                    by: 2
                ).compactMap { index in
                    guard index + 1 < orderedBoundaries.count else { return nil }
                    return (orderedBoundaries[index].time, orderedBoundaries[index + 1].time)
                }
                guard points.count >= 2 else { return }
                let y = size.height / 2 + 9
                for index in 0..<(points.count - 1) {
                    let start = points[index]
                    let end = points[index + 1]
                    if gaps.contains(where: {
                        start <= $0.0 + 0.001 && end >= $0.1 - 0.001
                    }) { continue }
                    var path = Path()
                    path.move(to: CGPoint(x: viewport.x(for: start, width: size.width), y: y))
                    path.addLine(to: CGPoint(x: viewport.x(for: end, width: size.width), y: y))
                    context.stroke(
                        path,
                        with: .color(color.opacity(0.34)),
                        style: StrokeStyle(lineWidth: 1, dash: [3, 4])
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct GeneratedKeyPointView: View {
    let point: SpatialGeneratedBoundaryKeyPoint
    let viewport: TimelineViewport
    let trackWidth: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.white.opacity(0.26))
            .frame(width: 9, height: 9)
            .rotationEffect(.degrees(45))
            .position(x: viewport.x(for: point.time, width: trackWidth), y: 42)
            .allowsHitTesting(false)
            .accessibilityLabel("自动边界定位点")
    }
}

private struct SpatialKeyPointView: View {
    let sourceID: UUID
    let point: SpatialKeyPoint
    let viewport: TimelineViewport
    let trackWidth: CGFloat
    let isSelected: Bool
    let sourceColor: Color
    @ObservedObject var viewModel: SpatialTimelineViewModel
    @Environment(\.sceneAdaptiveAccent) private var sceneAccent
    @State private var dragStartTime: Double?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(isSelected ? sceneAccent : sourceColor.opacity(0.72))
                .frame(width: isSelected ? 13 : 11, height: isSelected ? 13 : 11)
                .rotationEffect(.degrees(45))
                .shadow(color: sceneAccent.opacity(isSelected ? 0.65 : 0), radius: 7)
                .contentShape(Rectangle().size(width: 34, height: 34))
                .onTapGesture {
                    viewModel.selectKeyPoint(sourceID: sourceID, keyPointID: point.id)
                }
                .highPriorityGesture(
                    DragGesture(minimumDistance: 4)
                        .onChanged { value in
                            if dragStartTime == nil {
                                dragStartTime = point.time
                                viewModel.selectKeyPoint(sourceID: sourceID, keyPointID: point.id)
                            }
                            let delta = Double(value.translation.width / max(trackWidth, 1)) * viewport.span
                            viewModel.moveKeyPointTime(
                                sourceID: sourceID,
                                keyPointID: point.id,
                                proposedTime: (dragStartTime ?? point.time) + delta
                            )
                        }
                        .onEnded { _ in dragStartTime = nil }
                )

            if isSelected {
                Button(role: .destructive) {
                    viewModel.deleteKeyPoint(sourceID: sourceID, keyPointID: point.id)
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background { Circle().fill(Color.red.opacity(0.78)) }
                }
                .buttonStyle(.plain)
                .offset(y: -25)
            }
        }
        .position(x: viewport.x(for: point.time, width: trackWidth), y: 42)
        .accessibilityLabel("定位点 \(SpatialTimeText.string(point.time))")
    }
}

private struct TimelineNavigatorView: View {
    let duration: Double
    let viewport: TimelineViewport
    let labelWidth: CGFloat
    let timelineWidth: CGFloat
    @ObservedObject var viewModel: SpatialTimelineViewModel
    @Environment(\.sceneAdaptiveAccent) private var sceneAccent

    @State private var bodyOriginStart: Double?
    @State private var leadingOriginStart: Double?
    @State private var leadingFixedEnd: Double?
    @State private var trailingOriginEnd: Double?
    @State private var trailingFixedStart: Double?

    var body: some View {
        HStack(spacing: 12) {
            Text("时间范围")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(DreamTheme.tertiaryText)
                .frame(width: labelWidth, alignment: .leading)
            GeometryReader { proxy in
                let startX = CGFloat(viewport.startTime / max(duration, 1)) * proxy.size.width
                let width = CGFloat(viewport.span / max(duration, 1)) * proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.07)).frame(height: 8)
                    Capsule()
                        .fill(sceneAccent.opacity(0.24))
                        .overlay { Capsule().stroke(sceneAccent.opacity(0.65), lineWidth: 1) }
                        .frame(width: max(width, 22), height: 18)
                        .offset(x: startX)
                        .contentShape(Rectangle())
                        .gesture(bodyGesture(width: proxy.size.width))
                    navigatorHandle
                        .position(x: startX, y: proxy.size.height / 2)
                        .highPriorityGesture(leadingGesture(width: proxy.size.width))
                    navigatorHandle
                        .position(x: startX + max(width, 22), y: proxy.size.height / 2)
                        .highPriorityGesture(trailingGesture(width: proxy.size.width))
                }
                .frame(maxHeight: .infinity)
                .onTapGesture { viewModel.clearTimelineItemSelection() }
            }
            .frame(width: timelineWidth)
        }
    }

    private var navigatorHandle: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(sceneAccent)
            .frame(width: 5, height: 24)
            .contentShape(Rectangle().size(width: 24, height: 30))
    }

    private func bodyGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if bodyOriginStart == nil {
                    bodyOriginStart = viewport.startTime
                    viewModel.beginTimelineViewportInteraction()
                }
                let delta = Double(value.translation.width / max(width, 1)) * duration
                viewModel.setTimelineViewport(
                    startTime: (bodyOriginStart ?? viewport.startTime) + delta,
                    span: viewport.span
                )
            }
            .onEnded { _ in
                bodyOriginStart = nil
                viewModel.endTimelineViewportInteraction()
            }
    }

    private func leadingGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if leadingOriginStart == nil {
                    leadingOriginStart = viewport.startTime
                    leadingFixedEnd = viewport.endTime
                    viewModel.beginTimelineViewportInteraction()
                }
                let delta = Double(value.translation.width / max(width, 1)) * duration
                let end = leadingFixedEnd ?? viewport.endTime
                let start = min(
                    max((leadingOriginStart ?? viewport.startTime) + delta, 0),
                    end - min(TimelineViewport.minimumSpan, duration)
                )
                viewModel.setTimelineViewport(startTime: start, span: end - start)
            }
            .onEnded { _ in
                leadingOriginStart = nil
                leadingFixedEnd = nil
                viewModel.endTimelineViewportInteraction()
            }
    }

    private func trailingGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if trailingOriginEnd == nil {
                    trailingOriginEnd = viewport.endTime
                    trailingFixedStart = viewport.startTime
                    viewModel.beginTimelineViewportInteraction()
                }
                let delta = Double(value.translation.width / max(width, 1)) * duration
                let start = trailingFixedStart ?? viewport.startTime
                let end = min(
                    max((trailingOriginEnd ?? viewport.endTime) + delta,
                        start + min(TimelineViewport.minimumSpan, duration)),
                    duration
                )
                viewModel.setTimelineViewport(startTime: start, span: end - start)
            }
            .onEnded { _ in
                trailingOriginEnd = nil
                trailingFixedStart = nil
                viewModel.endTimelineViewportInteraction()
            }
    }
}

private struct TimelinePlayheadView: View {
    let currentTime: Double
    let viewport: TimelineViewport
    let timelineWidth: CGFloat
    let height: CGFloat
    let onScrub: (Double) -> Void
    @Environment(\.sceneAdaptiveAccent) private var sceneAccent
    @State private var dragStartTime: Double?

    var body: some View {
        let x = viewport.x(for: currentTime, width: timelineWidth)
        ZStack(alignment: .top) {
            Rectangle().fill(sceneAccent.opacity(0.86)).frame(width: 1.2, height: height - 4)
            Diamond()
                .fill(sceneAccent)
                .frame(width: 10, height: 10)
                .shadow(color: sceneAccent.opacity(0.55), radius: 5)
                .offset(y: -2)
                .contentShape(Rectangle().size(width: 34, height: 28))
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if dragStartTime == nil { dragStartTime = currentTime }
                            let delta = Double(value.translation.width / max(timelineWidth, 1)) * viewport.span
                            onScrub((dragStartTime ?? currentTime) + delta)
                        }
                        .onEnded { _ in dragStartTime = nil }
                )
        }
        .frame(width: 1.2, height: height, alignment: .top)
        .offset(x: x)
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
