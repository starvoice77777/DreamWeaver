import Foundation

enum SoundCategory: String, CaseIterable, Hashable, Equatable, Identifiable {
    case environment
    case atmosphere
    case anchor
    case detail
    case humanASMR
    case event

    var id: String { rawValue }

    var displayName: String {
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
        case .atmosphere: "连续的氛围声"
        case .anchor: "场景里的主要声音"
        case .detail: "轻巧的细节声"
        case .humanASMR: "近距离的柔和人声"
        case .event: "短暂而有记忆点的声音"
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

    var colorToken: ColorToken {
        switch self {
        case .environment: .night
        case .atmosphere: .rain
        case .anchor: .ember
        case .detail: .paper
        case .humanASMR: .lavender
        case .event: .gold
        }
    }
}

enum ColorToken: String, CaseIterable, Hashable, Equatable, Identifiable {
    case night
    case rain
    case ember
    case paper
    case lavender
    case gold

    var id: String { rawValue }
}

enum SoundDuration: String, CaseIterable, Hashable, Equatable, Identifiable {
    case short
    case medium
    case long

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .short: "短声"
        case .medium: "中等"
        case .long: "持续"
        }
    }

    var seconds: TimeInterval {
        switch self {
        case .short: 4
        case .medium: 12
        case .long: 60
        }
    }
}
