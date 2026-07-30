import Foundation
import Combine

@MainActor
final class MockPlaybackService: ObservableObject {
    @Published var isPlaying = false
    @Published var progress: Double = 0.18
    @Published var previewingAssetId: UUID?

    private var progressTimer: Timer?
    private var previewTimer: Timer?

    func togglePlay() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func play() {
        isPlaying = true
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isPlaying else { return }
                self.progress = min(self.progress + 0.004, 0.98)
            }
        }
    }

    func pause() {
        isPlaying = false
        progressTimer?.invalidate()
        progressTimer = nil
    }

    func togglePreview(assetId: UUID) {
        if previewingAssetId == assetId {
            stopPreview()
            return
        }
        previewingAssetId = assetId
        previewTimer?.invalidate()
        previewTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.stopPreview()
            }
        }
    }

    func stopPreview() {
        previewingAssetId = nil
        previewTimer?.invalidate()
        previewTimer = nil
    }
}
