import AVFoundation
import Combine
import SwiftUI
import UIKit

/// A silent, full-bleed AVPlayer layer that keeps a bundled video looping.
@MainActor
final class LoopingVideoPlayer: ObservableObject {
    let player = AVQueuePlayer()
    let isAvailable: Bool

    private var looper: AVPlayerLooper?
    private var shouldBePlaying = false

    init(
        resourceName: String,
        fileExtension: String,
        subdirectory: String,
        loopOverlap: TimeInterval = 0
    ) {
        player.isMuted = true
        player.actionAtItemEnd = .none

        // File-system-synchronised Xcode resource groups are copied to the
        // bundle root, while some build configurations preserve subfolders.
        // Support both layouts so the video is available in every target.
        let url = Bundle.main.url(
            forResource: resourceName,
            withExtension: fileExtension,
            subdirectory: subdirectory
        ) ?? Bundle.main.url(
            forResource: resourceName,
            withExtension: fileExtension
        )

        guard let url else {
            isAvailable = false
            return
        }

        isAvailable = true
        if loopOverlap > 0 {
            Task { [weak self] in
                let templateItem = await Self.makeLoopItem(
                    url: url,
                    overlapDuration: loopOverlap
                )
                self?.installLooper(with: templateItem)
            }
        } else {
            installLooper(with: AVPlayerItem(url: url))
        }
    }

    func play() {
        guard isAvailable else { return }
        shouldBePlaying = true
        if looper != nil {
            player.play()
        }
    }

    func pause() {
        shouldBePlaying = false
        player.pause()
    }

    private static func makeLoopItem(
        url: URL,
        overlapDuration: TimeInterval
    ) async -> AVPlayerItem {
        let asset = AVURLAsset(url: url)
        guard overlapDuration > 0 else {
            return AVPlayerItem(asset: asset)
        }

        let duration: CMTime
        let sourceTrack: AVAssetTrack
        let preferredTransform: CGAffineTransform
        let naturalSize: CGSize
        let nominalFrameRate: Float
        do {
            duration = try await asset.load(.duration)
            guard let loadedTrack = try await asset.loadTracks(withMediaType: .video).first else {
                return AVPlayerItem(asset: asset)
            }
            sourceTrack = loadedTrack
            preferredTransform = try await sourceTrack.load(.preferredTransform)
            naturalSize = try await sourceTrack.load(.naturalSize)
            nominalFrameRate = try await sourceTrack.load(.nominalFrameRate)
        } catch {
            return AVPlayerItem(asset: asset)
        }

        let overlap = CMTime(
            seconds: overlapDuration,
            preferredTimescale: max(duration.timescale, 600)
        )
        let composition = AVMutableComposition()
        guard duration.isNumeric,
              CMTimeCompare(duration, CMTimeMultiply(overlap, multiplier: 2)) > 0,
              let tailTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
              ),
              let headTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
              ) else {
            return AVPlayerItem(asset: asset)
        }

        let loopDuration = CMTimeSubtract(duration, overlap)
        let crossfadeStart = CMTimeSubtract(loopDuration, overlap)

        do {
            try tailTrack.insertTimeRange(
                CMTimeRange(start: overlap, duration: loopDuration),
                of: sourceTrack,
                at: .zero
            )
            try headTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: overlap),
                of: sourceTrack,
                at: crossfadeStart
            )
        } catch {
            return AVPlayerItem(asset: asset)
        }

        tailTrack.preferredTransform = preferredTransform
        headTrack.preferredTransform = preferredTransform

        let normalLayer = AVVideoCompositionLayerInstruction(
            configuration: .init(assetTrack: tailTrack)
        )
        let normalInstruction = AVVideoCompositionInstruction(
            configuration: .init(
                layerInstructions: [normalLayer],
                timeRange: CMTimeRange(start: .zero, duration: crossfadeStart)
            )
        )

        let transitionRange = CMTimeRange(start: crossfadeStart, duration: overlap)
        var tailConfiguration = AVVideoCompositionLayerInstruction.Configuration(
            assetTrack: tailTrack
        )
        tailConfiguration.addOpacityRamp(
            .init(timeRange: transitionRange, start: 1, end: 0)
        )
        let tailLayer = AVVideoCompositionLayerInstruction(
            configuration: tailConfiguration
        )

        var headConfiguration = AVVideoCompositionLayerInstruction.Configuration(
            assetTrack: headTrack
        )
        headConfiguration.addOpacityRamp(
            .init(timeRange: transitionRange, start: 0, end: 1)
        )
        let headLayer = AVVideoCompositionLayerInstruction(
            configuration: headConfiguration
        )

        let crossfadeInstruction = AVVideoCompositionInstruction(
            configuration: .init(
                layerInstructions: [headLayer, tailLayer],
                timeRange: transitionRange
            )
        )

        let transformedSize = naturalSize.applying(preferredTransform)
        let frameRate = nominalFrameRate > 0 ? nominalFrameRate : 24
        let videoComposition = AVVideoComposition(
            configuration: .init(
                frameDuration: CMTime(
                    value: 1,
                    timescale: CMTimeScale(frameRate.rounded())
                ),
                instructions: [normalInstruction, crossfadeInstruction],
                renderSize: CGSize(
                    width: abs(transformedSize.width),
                    height: abs(transformedSize.height)
                )
            )
        )

        let item = AVPlayerItem(asset: composition)
        item.videoComposition = videoComposition
        return item
    }

    private func installLooper(with templateItem: AVPlayerItem) {
        looper = AVPlayerLooper(player: player, templateItem: templateItem)
        if shouldBePlaying {
            player.play()
        }
    }
}

/// SwiftUI bridge for an AVPlayerLayer without system playback controls.
struct LoopingVideoBackdrop: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerLayerView {
        PlayerLayerView(player: player)
    }

    func updateUIView(_ view: PlayerLayerView, context: Context) {
        view.player = player
    }
}

final class PlayerLayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }

    private var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    init(player: AVPlayer) {
        super.init(frame: .zero)
        self.player = player
        playerLayer.videoGravity = .resizeAspectFill
        // AVPlayerLooper may briefly have no decoded frame while it swaps its
        // queue item. Keep the layer transparent in that interval so the
        // matching still cover underneath remains visible instead of flashing
        // the default black player surface.
        isOpaque = false
        backgroundColor = .clear
        playerLayer.backgroundColor = UIColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        return nil
    }
}
