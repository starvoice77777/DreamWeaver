import SwiftUI
import UIKit

/// Four-stop palette for emotional fluid scenes.
struct FluidColorPalette: Hashable, Identifiable {
    let id: String
    let name: String
    let primary: Color
    let secondary: Color
    let tertiary: Color
    let highlight: Color

    private init(
        id: String,
        name: String,
        primary: UInt32,
        secondary: UInt32,
        tertiary: UInt32,
        highlight: UInt32
    ) {
        self.id = id
        self.name = name
        self.primary = Color(hex: primary)
        self.secondary = Color(hex: secondary)
        self.tertiary = Color(hex: tertiary)
        self.highlight = Color(hex: highlight)
    }

    init(
        id: String,
        name: String,
        primary: Color,
        secondary: Color,
        tertiary: Color,
        highlight: Color
    ) {
        self.id = id
        self.name = name
        self.primary = primary
        self.secondary = secondary
        self.tertiary = tertiary
        self.highlight = highlight
    }

    /// User-provided combinations. Every visual mode cycles through the same
    /// four palettes so color identity stays consistent while motion changes.
    static func palettes(for _: FluidSceneType) -> [FluidColorPalette] {
        [
            FluidColorPalette(
                id: "jadeMist",
                name: "Jade Mist",
                primary: 0x659287,
                secondary: 0x88BDA4,
                tertiary: 0xB1D3B9,
                highlight: 0xE6F2DD
            ),
            FluidColorPalette(
                id: "mossCream",
                name: "Moss Cream",
                primary: 0x546B41,
                secondary: 0x99AD7A,
                tertiary: 0xDCCCAC,
                highlight: 0xFFF8EC
            ),
            FluidColorPalette(
                id: "skySand",
                name: "Sky Sand",
                primary: 0x81A6C6,
                secondary: 0xAACDDC,
                tertiary: 0xF3E3D0,
                highlight: 0xD2C4B4
            ),
            FluidColorPalette(
                id: "blushGlow",
                name: "Blush Glow",
                primary: 0xFCF8F8,
                secondary: 0xFBEFEF,
                tertiary: 0xF9DFDF,
                highlight: 0xF5AFAF
            )
        ]
    }

    func blended(toward other: FluidColorPalette, amount: Double) -> FluidColorPalette {
        let t = max(0, min(1, amount))
        return FluidColorPalette(
            id: "blend-\(id)-\(other.id)",
            name: name,
            primary: Self.mix(primary, other.primary, t),
            secondary: Self.mix(secondary, other.secondary, t),
            tertiary: Self.mix(tertiary, other.tertiary, t),
            highlight: Self.mix(highlight, other.highlight, t)
        )
    }

    private static func mix(_ a: Color, _ b: Color, _ t: Double) -> Color {
        let ua = UIColor(a)
        let ub = UIColor(b)
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        ua.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        ub.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return Color(
            red: ar + (br - ar) * t,
            green: ag + (bg - ag) * t,
            blue: ab + (bb - ab) * t,
            opacity: aa + (ba - aa) * t
        )
    }
}
