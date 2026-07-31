import SwiftUI

enum DreamTheme {
    static let midnight = Color(hex: 0x080B16)
    static let deepBlue = Color(hex: 0x11182A)
    static let mistBlue = Color(hex: 0x8197B5)
    static let warmApricot = Color(hex: 0xD79A72)
    static let moonWhite = Color(hex: 0xF3F0EA)
    static let softLavender = Color(hex: 0x8D87A8)

    static let panel = Color.white.opacity(0.10)
    static let panelStrong = Color.white.opacity(0.14)
    static let divider = Color.white.opacity(0.08)
    static let secondaryText = Color.white.opacity(0.62)
    static let tertiaryText = Color.white.opacity(0.42)

    static let backgroundGradient = LinearGradient(
        colors: [midnight, deepBlue],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Matches the scene mix disk fill so chrome panels read at the same opacity.
    static let diskSurface = Color(hex: 0x1A2740)
    static let diskSurfaceOpacity: Double = 0.9
    static var chromeSurface: Color { diskSurface.opacity(diskSurfaceOpacity) }
    static let chromeStroke = Color.white.opacity(0.10)

    /// Shared show/hide timing for scene disk, chrome controls, and tab bar.
    static let chromeVisibilityDuration: TimeInterval = 0.45

    static var chromeVisibilityAnimation: Animation {
        .easeInOut(duration: chromeVisibilityDuration)
    }

    static var chromeVisibilityTransition: AnyTransition {
        .opacity.combined(with: .scale(scale: 0.98))
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

struct ScenePalette: Hashable, Codable {
    var top: UInt32
    var mid: UInt32
    var bottom: UInt32
    var accent: UInt32

    var topColor: Color { Color(hex: top) }
    var midColor: Color { Color(hex: mid) }
    var bottomColor: Color { Color(hex: bottom) }
    var accentColor: Color { Color(hex: accent) }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [topColor, midColor, bottomColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
