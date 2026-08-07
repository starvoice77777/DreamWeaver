import Foundation

nonisolated enum ScenePlaybackMode: String, Codable, Sendable {
    case oneshot
    case loop
    case boundedLoop = "bounded_loop"
}

/// One independently editable timeline item. It is deliberately separate from
/// `SceneSourceGroup`: twenty narration files remain twenty clips while sharing
/// one spatial control and one radial gain.
nonisolated struct SceneAudioClip: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let sourceGroupID: UUID
    var assetID: UUID?
    var resourceKey: String?
    var startSeconds: Double
    var endSeconds: Double
    var sourceOffsetSeconds: Double
    var playbackMode: ScenePlaybackMode
    var crossfadeMilliseconds: Int
    var fadeInMilliseconds: Int
    var fadeOutMilliseconds: Int
    var phraseID: UUID?
    var textCueID: UUID?
    var masteringProfileKey: String?

    var duration: Double { max(endSeconds - startSeconds, 0) }

    init(
        id: UUID = UUID(),
        sourceGroupID: UUID,
        assetID: UUID? = nil,
        resourceKey: String? = nil,
        startSeconds: Double,
        endSeconds: Double,
        sourceOffsetSeconds: Double = 0,
        playbackMode: ScenePlaybackMode,
        crossfadeMilliseconds: Int = 0,
        fadeInMilliseconds: Int = 0,
        fadeOutMilliseconds: Int = 0,
        phraseID: UUID? = nil,
        textCueID: UUID? = nil,
        masteringProfileKey: String? = nil
    ) {
        self.id = id
        self.sourceGroupID = sourceGroupID
        self.assetID = assetID
        self.resourceKey = resourceKey
        let clampedStart = max(startSeconds, 0)
        self.startSeconds = clampedStart
        self.endSeconds = max(endSeconds, clampedStart)
        self.sourceOffsetSeconds = max(sourceOffsetSeconds, 0)
        self.playbackMode = playbackMode
        self.crossfadeMilliseconds = max(crossfadeMilliseconds, 0)
        self.fadeInMilliseconds = max(fadeInMilliseconds, 0)
        self.fadeOutMilliseconds = max(fadeOutMilliseconds, 0)
        self.phraseID = phraseID
        self.textCueID = textCueID
        self.masteringProfileKey = masteringProfileKey
    }
}
