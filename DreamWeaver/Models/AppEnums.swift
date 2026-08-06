import Foundation

enum AppTab: String, CaseIterable, Identifiable {
    case now
    /// Elevated center entry — create / save personal scenes (闲鱼「发闲置」位).
    case create
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .now: return "此刻"
        case .create: return "创建"
        case .profile: return "我的"
        }
    }

    /// Whether this tab is the raised center CTA (not an equal-weight peer).
    var isElevatedCenter: Bool { self == .create }

    /// Filled glyph — selected (正).
    var systemImageFill: String {
        switch self {
        case .now: return "headphones"
        case .create: return "plus"
        case .profile: return "person.crop.circle.fill"
        }
    }

    /// Outline glyph — unselected (反).
    var systemImageOutline: String {
        switch self {
        case .now: return "headphones"
        case .create: return "plus"
        case .profile: return "person.crop.circle"
        }
    }

    var systemImage: String { systemImageFill }
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

    var systemImage: String {
        switch self {
        case .frequent: return "clock.fill"
        case .favorites: return "heart.fill"
        case .nature: return "leaf.fill"
        case .rainyNight: return "cloud.rain.fill"
        case .ocean: return "water.waves"
        case .forest: return "tree.fill"
        case .voice: return "waveform"
        case .companion: return "person.2.fill"
        case .breath: return "wind"
        case .lightMusic: return "music.note"
        case .whisper: return "ear.badge.waveform"
        }
    }
}

enum TimerOption: String, CaseIterable, Identifiable, Codable {
    case autoStop = "自动"
    case tenMinutes = "10分钟"
    case thirtyMinutes = "30分钟"
    case oneHour = "60分钟"
    case forever = "一直"
    /// Demo / filming only — about 45 seconds with layered fade.
    case demoAccelerated = "演示加速"

    var id: String { rawValue }

    var minutes: Int? {
        switch self {
        case .autoStop: return 45
        case .tenMinutes: return 10
        case .thirtyMinutes: return 30
        case .oneHour: return 60
        case .forever: return nil
        case .demoAccelerated: return nil
        }
    }

    /// Wall-clock duration for countdown (accelerated uses seconds, not minutes).
    var countdownSeconds: TimeInterval? {
        switch self {
        case .demoAccelerated: return 45
        case .tenMinutes, .thirtyMinutes, .oneHour:
            return TimeInterval((minutes ?? 0) * 60)
        case .autoStop:
            // Default sleep timer when the user doesn't choose a fixed chip.
            return TimeInterval(45 * 60)
        case .forever:
            return nil
        }
    }

    /// Compact label for the control-bar timer button.
    var shortLabel: String {
        switch self {
        case .autoStop: return "自动"
        case .tenMinutes: return "10"
        case .thirtyMinutes: return "30"
        case .oneHour: return "60"
        case .forever: return "一直"
        case .demoAccelerated: return "演示"
        }
    }

    /// Only these options show live countdown fill on the chip.
    var showsCountdownFill: Bool {
        switch self {
        case .tenMinutes, .thirtyMinutes, .oneHour, .demoAccelerated: return true
        default: return false
        }
    }

    static var userFacingCases: [TimerOption] {
        [.autoStop, .tenMinutes, .thirtyMinutes, .oneHour, .forever]
    }

    static var demoCases: [TimerOption] {
        userFacingCases + [.demoAccelerated]
    }
}

enum SoundLibrarySegment: String, CaseIterable, Identifiable {
    case mine = "我的"
    case community = "全部"
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
