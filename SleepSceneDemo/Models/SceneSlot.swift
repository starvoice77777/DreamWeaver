import Foundation

enum SceneSlotKind: String, CaseIterable, Hashable, Equatable, Identifiable {
    case environment
    case atmosphere
    case anchor
    case detail
    case humanASMR
    case event

    var id: String { rawValue }

    var title: String {
        switch self {
        case .environment: "环境"
        case .atmosphere: "氛围"
        case .anchor: "主体"
        case .detail: "细节"
        case .humanASMR: "ASMR"
        case .event: "事件"
        }
    }

    var subtitle: String {
        switch self {
        case .environment: "远处的环境底色"
        case .atmosphere: "持续的氛围"
        case .anchor: "场景焦点"
        case .detail: "轻巧的细节"
        case .humanASMR: "近距离人声"
        case .event: "短暂事件"
        }
    }

    var acceptedCategories: Set<SoundCategory> {
        switch self {
        case .environment: [.environment]
        case .atmosphere: [.atmosphere]
        case .anchor: [.anchor]
        case .detail: [.detail]
        case .humanASMR: [.humanASMR]
        case .event: [.event]
        }
    }

    var systemImage: String {
        switch self {
        case .environment: "moon.stars"
        case .atmosphere: "cloud.rain"
        case .anchor: "flame"
        case .detail: "sparkles"
        case .humanASMR: "waveform"
        case .event: "bell"
        }
    }

    var illustrationLayer: IllustrationLayer {
        switch self {
        case .environment: .background
        case .atmosphere: .atmosphere
        case .anchor: .subject
        case .detail, .humanASMR: .foreground
        case .event: .motion
        }
    }
}

enum IllustrationLayer: String, Hashable, Equatable {
    case background
    case atmosphere
    case subject
    case foreground
    case motion
}

struct SceneSlot: Identifiable, Equatable, Hashable {
    let kind: SceneSlotKind

    var id: String { kind.id }
    var title: String { kind.title }
    var subtitle: String { kind.subtitle }
    var acceptedCategories: Set<SoundCategory> { kind.acceptedCategories }
    var systemImage: String { kind.systemImage }

    static var all: [SceneSlot] { SceneSlotKind.allCases.map(SceneSlot.init(kind:)) }
}
