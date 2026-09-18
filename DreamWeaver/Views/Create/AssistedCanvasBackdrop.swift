import SwiftUI

/// Visual-only backdrop for assisted creation. Playback remains owned by the
/// existing spatial editor and AppState playback service.
struct AssistedCanvasBackdrop: View {
    let framework: AssistedCreationFramework

    var body: some View {
        ZStack {
            switch framework {
            case .boundaryGate:
                AssistedTrainCabinBackdrop()
            case .enclosureControl, .depthReveal, .focusSelector, .nearfieldWidth:
                AssistedAbstractFrameworkBackdrop(framework: framework)
            }
        }
        .background(DreamTheme.diskSurface.opacity(0.78))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(DreamTheme.chromeStroke, lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}

private struct AssistedTrainCabinBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            let layout = TrainCabinArtworkLayout(containerSize: proxy.size)

            ZStack {
                RoundedRectangle(cornerRadius: layout.windowCornerRadius)
                    .fill(Color.white.opacity(0.96))
                    .frame(width: layout.windowRect.width, height: layout.windowRect.height)
                    .position(x: layout.windowRect.midX, y: layout.windowRect.midY)

                Image("TrainCabin")
                    .resizable()
                    .scaledToFill()
            }
        }
    }
}

private struct TrainCabinArtworkLayout {
    private static let sourceSize = CGSize(width: 900, height: 1_200)
    private static let sourceWindow = CGRect(x: 151, y: 237, width: 598, height: 514)

    let windowRect: CGRect
    let windowCornerRadius: CGFloat

    init(containerSize: CGSize) {
        let scale = max(
            containerSize.width / Self.sourceSize.width,
            containerSize.height / Self.sourceSize.height
        )
        let renderedSize = CGSize(
            width: Self.sourceSize.width * scale,
            height: Self.sourceSize.height * scale
        )
        let origin = CGPoint(
            x: (containerSize.width - renderedSize.width) / 2,
            y: (containerSize.height - renderedSize.height) / 2
        )

        windowRect = CGRect(
            x: origin.x + Self.sourceWindow.minX * scale,
            y: origin.y + Self.sourceWindow.minY * scale,
            width: Self.sourceWindow.width * scale,
            height: Self.sourceWindow.height * scale
        )
        windowCornerRadius = 52 * scale
    }
}

private struct AssistedAbstractFrameworkBackdrop: View {
    let framework: AssistedCreationFramework

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Circle()
                    .fill(DreamTheme.diskSurface.opacity(0.88))
                    .frame(width: proxy.size.height * 0.90)

                Circle()
                    .stroke(
                        DreamTheme.divider,
                        style: StrokeStyle(lineWidth: 1, dash: [4, 7])
                    )
                    .frame(width: proxy.size.height * 0.62)

                Image(systemName: framework.systemImage)
                    .font(.system(size: 62, weight: .ultraLight))
                    .foregroundStyle(DreamTheme.secondaryText.opacity(0.28))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
