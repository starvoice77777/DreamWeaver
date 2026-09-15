import Foundation

struct SoundElement: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    let category: SoundCategory
    let systemImage: String
    let colorToken: ColorToken
    let defaultSlot: SceneSlotKind
    let duration: SoundDuration
    let isContinuous: Bool

    static let catalog: [SoundElement] = [
        SoundElement(id: "rain", name: "Rain", subtitle: "窗外细密的雨声", category: .atmosphere, systemImage: "cloud.rain", colorToken: .rain, defaultSlot: .atmosphere, duration: .long, isContinuous: true),
        SoundElement(id: "night-ambience", name: "Night Ambience", subtitle: "夜色里的安静底噪", category: .environment, systemImage: "moon.stars", colorToken: .night, defaultSlot: .environment, duration: .long, isContinuous: true),
        SoundElement(id: "fireplace", name: "Fireplace", subtitle: "安静而温暖的炉火", category: .anchor, systemImage: "fireplace", colorToken: .ember, defaultSlot: .anchor, duration: .long, isContinuous: true),
        SoundElement(id: "page-turning", name: "Page Turning", subtitle: "书页翻动的细响", category: .detail, systemImage: "book.pages", colorToken: .paper, defaultSlot: .detail, duration: .short, isContinuous: false),
        SoundElement(id: "footsteps", name: "Footsteps", subtitle: "远处缓慢的脚步", category: .event, systemImage: "figure.walk", colorToken: .night, defaultSlot: .event, duration: .medium, isContinuous: false),
        SoundElement(id: "asmr-mouth-sounds", name: "ASMR Mouth Sounds", subtitle: "近距离柔和气音", category: .humanASMR, systemImage: "waveform", colorToken: .lavender, defaultSlot: .humanASMR, duration: .medium, isContinuous: false),
        SoundElement(id: "campfire", name: "Campfire", subtitle: "篝火轻轻噼啪作响", category: .anchor, systemImage: "flame", colorToken: .gold, defaultSlot: .anchor, duration: .long, isContinuous: true),
        SoundElement(id: "clock", name: "Clock", subtitle: "墙上时钟的轻响", category: .event, systemImage: "clock", colorToken: .gold, defaultSlot: .event, duration: .short, isContinuous: false)
    ]

    var illustrationKind: IllustrationKind {
        switch id {
        case "rain": .rain
        case "night-ambience": .nightWindow
        case "fireplace": .fireplace
        case "page-turning": .book
        case "footsteps": .footprints
        case "asmr-mouth-sounds": .asmr
        case "campfire": .campfire
        case "clock": .clock
        default: .ambient
        }
    }
}

enum IllustrationKind: String, Hashable, Equatable {
    case ambient
    case nightWindow
    case rain
    case fireplace
    case campfire
    case book
    case footprints
    case asmr
    case clock
}
