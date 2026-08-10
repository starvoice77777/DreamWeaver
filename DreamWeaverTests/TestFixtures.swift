import CoreGraphics
import Foundation
@testable import DreamWeaver

nonisolated enum TestFixtures {
    static let sceneID = UUID(uuidString: "10000000-0000-4000-8000-000000000001")!
    static let groupID = UUID(uuidString: "20000000-0000-4000-8000-000000000001")!
    static let secondGroupID = UUID(uuidString: "20000000-0000-4000-8000-000000000002")!
    static let firstClipID = UUID(uuidString: "30000000-0000-4000-8000-000000000001")!
    static let secondClipID = UUID(uuidString: "30000000-0000-4000-8000-000000000002")!
    static let thirdClipID = UUID(uuidString: "30000000-0000-4000-8000-000000000003")!
    static let assetID = UUID(uuidString: "40000000-0000-4000-8000-000000000001")!
    static let phraseID = UUID(uuidString: "50000000-0000-4000-8000-000000000001")!
    static let textCueID = UUID(uuidString: "60000000-0000-4000-8000-000000000001")!
    static let curveID = UUID(uuidString: "70000000-0000-4000-8000-000000000001")!

    static func group(
        id: UUID = groupID,
        position: SpatialPosition = SpatialPosition(angle: 0, radius: 0.5),
        keyframes: [ScenePositionKeyframe] = []
    ) -> SceneSourceGroup {
        SceneSourceGroup(
            id: id,
            name: "Test source",
            symbolName: "waveform",
            layer: .ambience,
            defaultPosition: position,
            positionKeyframes: keyframes
        )
    }

    static func clip(
        id: UUID = firstClipID,
        groupID: UUID = groupID,
        start: Double = 1,
        end: Double = 3,
        mode: ScenePlaybackMode = .oneshot
    ) -> SceneAudioClip {
        SceneAudioClip(
            id: id,
            sourceGroupID: groupID,
            assetID: assetID,
            resourceKey: "rain_soft",
            startSeconds: start,
            endSeconds: end,
            playbackMode: mode
        )
    }

    static func editorSource(
        id: UUID = firstClipID,
        groupID: UUID? = groupID,
        materialID: String? = "rain",
        assetID: UUID? = nil,
        resourceName: String? = "rain_soft",
        keyPoints: [SpatialKeyPoint] = [
            SpatialKeyPoint(
                id: UUID(uuidString: "80000000-0000-4000-8000-000000000001")!,
                time: 0,
                position: CGPoint(x: 0, y: -0.5),
                interpolation: .smoothstep
            )
        ],
        start: Double = 0,
        duration: Double = 10,
        looping: Bool? = true,
        isVoice: Bool = false
    ) -> SpatialEditorSource {
        SpatialEditorSource(
            id: id,
            sourceGroupID: groupID,
            materialID: materialID,
            assetID: assetID,
            resourceName: resourceName,
            name: isVoice ? "Voice" : "Rain",
            iconName: isVoice ? "quote.bubble" : "cloud.rain",
            theme: isVoice ? .narration : .rain,
            defaultPosition: CGPoint(x: 0, y: -0.5),
            keyPoints: keyPoints,
            audioStartTime: start,
            audioDuration: duration,
            isLooping: looping,
            sourceOffsetSeconds: 0.25,
            crossfadeMilliseconds: looping == true ? 900 : 0,
            fadeInMilliseconds: 100,
            fadeOutMilliseconds: 200,
            isVoice: isVoice
        )
    }
}
