import CoreGraphics
import Foundation

/// Stable framework identifiers shared by assisted creation and the backend contract.
enum AssistedCreationFramework: String, CaseIterable, Identifiable, Hashable, Codable {
    case boundaryGate = "boundary_gate"
    case enclosureControl = "enclosure_control"
    case depthReveal = "depth_reveal"
    case focusSelector = "focus_selector"
    case nearfieldWidth = "nearfield_width"

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .boundaryGate: "内外边界"
        case .enclosureControl: "稳定包裹"
        case .depthReveal: "远中近景深"
        case .focusSelector: "多物体焦点"
        case .nearfieldWidth: "近场宽度"
        }
    }

    var resultDescription: LocalizedStringResource {
        switch self {
        case .boundaryGate: "调节窗外声音有多明显"
        case .enclosureControl: "在丰富与安稳之间选择"
        case .depthReveal: "让近处或远处成为主景"
        case .focusSelector: "选择此刻更想听清的对象"
        case .nearfieldWidth: "调整两侧声音展开的程度"
        }
    }

    var systemImage: String {
        switch self {
        case .boundaryGate: "window.vertical.closed"
        case .enclosureControl: "circle.hexagongrid.fill"
        case .depthReveal: "mountain.2.fill"
        case .focusSelector: "scope"
        case .nearfieldWidth: "waveform.path.ecg.rectangle"
        }
    }

    var zones: [AssistedFrameworkZone] {
        switch self {
        case .boundaryGate: [.outside, .inside]
        case .enclosureControl: [.base, .surround, .detail]
        case .depthReveal: [.far, .mid, .near]
        case .focusSelector: [.base, .objectA, .objectB, .objectC]
        case .nearfieldWidth: [.background, .leftNear, .rightNear, .frontCompanion]
        }
    }
}

enum AssistedFrameworkZone: String, Identifiable, Hashable, Codable {
    case outside, inside, base, surround, detail, far, mid, near
    case objectA = "object_a"
    case objectB = "object_b"
    case objectC = "object_c"
    case background
    case leftNear = "left_near"
    case rightNear = "right_near"
    case frontCompanion = "front_companion"

    var id: String { rawValue }

    var editorPosition: CGPoint {
        switch self {
        case .outside, .far: CGPoint(x: 0, y: -0.78)
        case .inside, .base, .background: CGPoint(x: 0, y: 0.44)
        case .surround, .mid: CGPoint(x: -0.48, y: -0.18)
        case .detail, .near, .frontCompanion: CGPoint(x: 0.36, y: -0.24)
        case .objectA, .leftNear: CGPoint(x: -0.58, y: 0.02)
        case .objectB, .rightNear: CGPoint(x: 0.58, y: 0.02)
        case .objectC: CGPoint(x: 0, y: -0.50)
        }
    }
}

struct AssistedSoundSelection: Identifiable, Equatable {
    let sourceID: UUID
    let keyPointID: UUID
    let material: SpatialEditorMaterial
    let zone: AssistedFrameworkZone
    let isSystemSupplement: Bool

    var id: String { material.id }
}

enum AssistedDraftMutationResult: Equatable {
    case added
    case alreadySelected
    case invalidZone
    case maximumReached
}

/// Ephemeral second-layer draft. It converts losslessly into the existing third-layer editor seed.
struct AssistedCreationDraft: Equatable {
    static let maximumSoundCount = 4

    let id: UUID
    let framework: AssistedCreationFramework
    var sceneName: String
    private(set) var selections: [AssistedSoundSelection] = []

    init(
        id: UUID = UUID(),
        framework: AssistedCreationFramework,
        sceneName: String
    ) {
        self.id = id
        self.framework = framework
        self.sceneName = sceneName
    }

    mutating func add(
        _ material: SpatialEditorMaterial,
        to zone: AssistedFrameworkZone,
        isSystemSupplement: Bool = false
    ) -> AssistedDraftMutationResult {
        guard framework.zones.contains(zone) else { return .invalidZone }
        guard !selections.contains(where: { $0.material.id == material.id }) else {
            return .alreadySelected
        }
        guard selections.count < Self.maximumSoundCount else { return .maximumReached }
        selections.append(
            AssistedSoundSelection(
                sourceID: UUID(),
                keyPointID: UUID(),
                material: material,
                zone: zone,
                isSystemSupplement: isSystemSupplement
            )
        )
        return .added
    }

    mutating func remove(materialID: String) {
        selections.removeAll { $0.material.id == materialID }
    }

    func makeEditorSeed(duration: Double = 120) -> SpatialEditorSeed {
        let sources = selections.map { selection in
            let material = selection.material
            let position = selection.zone.editorPosition
            return SpatialEditorSource(
                id: selection.sourceID,
                materialID: material.id,
                assetID: material.assetID,
                resourceName: material.resourceName,
                name: material.name,
                iconName: material.iconName,
                theme: material.theme,
                defaultPosition: position,
                keyPoints: [
                    SpatialKeyPoint(
                        id: selection.keyPointID,
                        time: 0,
                        position: position,
                        createdByUser: true
                    )
                ],
                audioDuration: material.audioDuration ?? duration,
                isLooping: !material.isVoice,
                crossfadeMilliseconds: material.isVoice ? nil : 500,
                fadeInMilliseconds: material.isVoice ? 0 : 500,
                fadeOutMilliseconds: material.isVoice ? 0 : 500,
                isVoice: material.isVoice
            )
        }
        return SpatialEditorSeed(
            draftID: id,
            privateSceneID: nil,
            sceneName: sceneName,
            soundSources: sources,
            textCues: [],
            durationSeconds: duration,
            sourceSceneID: nil,
            sourceSceneSubtitle: nil
        )
    }
}
