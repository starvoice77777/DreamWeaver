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

    init(resourceName: String, fileExtension: String, subdirectory: String) {
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

        looper = AVPlayerLooper(
            player: player,
            templateItem: AVPlayerItem(url: url)
        )
        isAvailable = true
    }

    func play() {
        guard isAvailable else { return }
        player.play()
    }

    func pause() {
        player.pause()
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
        playerLayer.backgroundColor = UIColor.black.cgColor
    }

    required init?(coder: NSCoder) {
        return nil
    }
}
