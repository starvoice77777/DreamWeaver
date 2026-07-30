import Foundation

enum AppTab: String, CaseIterable, Identifiable {
    case now
    case scenes
    case sounds
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .now: return "此刻"
        case .scenes: return "全部"
        case .sounds: return "声音库"
        case .profile: return "我的"
        }
    }

    var systemImage: String {
        switch self {
        case .now: return "moon.stars.fill"
        case .scenes: return "square.stack.3d.up.fill"
        case .sounds: return "waveform"
        case .profile: return "person.crop.circle"
        }
    }
}

enum SceneCategory: String, CaseIterable, Identifiable, Codable, Hashable {
    case frequent = "常用"
    case favorites = "收藏"
    case nature = "自然"
    case rainyNight = "雨夜"
    case ocean = "海洋"
    case forest = "森林"
    case voice = "人声"
    case companion = "陪伴"
    case breath = "呼吸"
    case lightMusic = "轻音乐"
    case whisper = "耳语"

    var id: String { rawValue }
}

enum TimerOption: String, CaseIterable, Identifiable, Codable {
    case autoStop = "适时停止"
    case tenMinutes = "10分钟"
    case thirtyMinutes = "30分钟"
    case oneHour = "1小时"
    case forever = "一直播放"

    var id: String { rawValue }

    var minutes: Int? {
        switch self {
        case .autoStop: return 45
        case .tenMinutes: return 10
        case .thirtyMinutes: return 30
        case .oneHour: return 60
        case .forever: return nil
        }
    }

    /// Only these options show live countdown fill on the chip.
    var showsCountdownFill: Bool {
        switch self {
        case .tenMinutes, .thirtyMinutes, .oneHour: return true
        default: return false
        }
    }
}

enum SoundLibrarySegment: String, CaseIterable, Identifiable {
    case mine = "我的"
    case community = "社区"
    case favorites = "收藏声音"

    var id: String { rawValue }
}

enum SoundAssetKind: String, Codable, CaseIterable, Identifiable {
    case recording = "我的录音"
    case seed = "声音种子"
    case community = "社区声音"

    var id: String { rawValue }

    var isPersonal: Bool {
        self == .recording || self == .seed
    }
}

enum PersonRelation: String, CaseIterable, Identifiable, Codable {
    case family = "家人"
    case partner = "伴侣"
    case friend = "朋友"
    case custom = "自定义"

    var id: String { rawValue }
}

enum DistanceLabel: String, Codable {
    case near = "靠近"
    case medium = "适中"
    case far = "远处"

    static func from(radius: Double) -> DistanceLabel {
        if radius < 0.38 { return .near }
        if radius < 0.68 { return .medium }
        return .far
    }
}

enum MixBoardSelection: Equatable {
    case mine
    case preset(UUID)

    var isMine: Bool {
        if case .mine = self { return true }
        return false
    }
}
