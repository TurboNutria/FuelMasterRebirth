import DomainLayer
import SwiftUI

/// Colour tokens from the design canvas (Fundamentos and Apariencia). Light / dark pairs.
/// Dark mode is one neutral graphite ramp (not black, not navy): background, then surface and
/// cell a step lighter each, with hairlines a little above the background.
public enum ColorTokens {
    public static let background = Color(light: 0xFAFAFA, dark: 0x1A1A1D)
    public static let surface = Color(light: 0xFFFFFF, dark: 0x242428)
    public static let cell = Color(light: 0xF2F2F2, dark: 0x323236)
    // Increase Contrast: hairlines, outlines and secondary text a step further from the background.
    public static let separator = Color(light: 0xEFEFEF, dark: 0x313136, highLight: 0xC9CCD3, highDark: 0x5A5A60)
    /// Outline of unselected filter chips.
    public static let chipBorder = Color(light: 0xC9CCD3, dark: 0x4A4A50, highLight: 0x8E929B, highDark: 0x7A7A82)
    public static let textPrimary = Color(light: 0x1C1C1E, dark: 0xF4F4F5, highLight: 0x000000, highDark: 0xFFFFFF)
    public static let textSecondary = Color(light: 0x5B5F6B, dark: 0xA1A1AA, highLight: 0x3C3F47, highDark: 0xD4D4D8)
    public static let closed = Color(light: 0x6B6F7A, dark: 0xA1A1AA, highLight: 0x3C3F47, highDark: 0xD4D4D8)
    public static let offline = Color(light: 0xC42B1C, dark: 0xC42B1C, highLight: 0x9E1F13, highDark: 0x9E1F13)
    /// "↓ 0,020 €" / "↑ 0,010 €" in Favoritos (canvas colours, lighter in dark mode).
    public static let priceDown = Color(light: 0x1E5E2C, dark: 0x5BD07A, highLight: 0x14461F, highDark: 0x8BE5A3)
    public static let priceUp = Color(light: 0xA3261B, dark: 0xFF7B70, highLight: 0x7F1D14, highDark: 0xFFA9A1)
}

/// Accent presets: fill, label on the fill, and the tint used for text and icons on light surfaces.
public struct AccentColors: Sendable {
    public let fill: Color
    public let onFill: Color
    public let tint: Color

    public static func colors(for choice: AccentChoice) -> AccentColors {
        switch choice {
        // Tints are for text and icons: lighter in dark mode so they stay readable on graphite, and
        // darker with Increase Contrast (canvas: orange text becomes #8A3D00).
        case .preset(.orange): AccentColors(fill: Color(light: 0xF28C28, dark: 0xF59E45), onFill: Color(hex: 0x2B1300),
                                             tint: Color(light: 0xA84B00, dark: 0xF59E45, highLight: 0x8A3D00, highDark: 0xFFBE7A))
        case .preset(.blue): AccentColors(fill: Color(hex: 0x0B63C4), onFill: .white,
                                           tint: Color(light: 0x0B63C4, dark: 0x5AA2F0, highLight: 0x084D99, highDark: 0x8EC1F7))
        case .preset(.green): AccentColors(fill: Color(hex: 0x1E7B34), onFill: .white,
                                            tint: Color(light: 0x1E7B34, dark: 0x4CC36B, highLight: 0x166028, highDark: 0x84DC9C))
        case .preset(.purple): AccentColors(fill: Color(hex: 0x7C3AED), onFill: .white,
                                             tint: Color(light: 0x7C3AED, dark: 0xA78BFA, highLight: 0x6425C9, highDark: 0xC9B8FC))
        case .preset(.pink): AccentColors(fill: Color(hex: 0xD6336C), onFill: .white,
                                           tint: Color(light: 0xB8285A, dark: 0xF472A6, highLight: 0x9A1F4A, highDark: 0xF9A8C9))
        case .preset(.graphite): AccentColors(fill: Color(hex: 0x4B5563), onFill: .white,
                                               tint: Color(light: 0x4B5563, dark: 0xA1A1AA, highLight: 0x374151, highDark: 0xD4D4D8))
        case .custom(let rgb):
            AccentColors(fill: Color(rgb), onFill: rgb.prefersDarkLabel ? Color(hex: 0x1C1C1E) : .white, tint: Color(rgb))
        }
    }
}

/// Chip colours per price level and scale: background and text. No outlines, so every fill
/// must stand apart from the page background on its own.
public struct PriceLevelColors: Sendable {
    public let background: Color
    public let foreground: Color

    public static func colors(for level: PriceLevel, scale: PriceScale) -> PriceLevelColors {
        switch (scale, level) {
        case (.trafficLight, .cheap):
            PriceLevelColors(background: Color(light: 0x1E7B34, dark: 0x4CC36B), foreground: Color(light: 0xFFFFFF, dark: 0x062B12))
        case (.trafficLight, .average):
            PriceLevelColors(background: Color(hex: 0xFFEAA0), foreground: Color(hex: 0x5C4400))
        case (.trafficLight, .expensive):
            PriceLevelColors(background: Color(hex: 0xEF5350), foreground: Color(hex: 0x2B0000))
        case (.blueOrange, .cheap):
            PriceLevelColors(background: Color(hex: 0x0B63C4), foreground: .white)
        case (.blueOrange, .average):
            PriceLevelColors(background: Color(light: 0xE4E6EB, dark: 0x3A3A40), foreground: Color(light: 0x1C1C1E, dark: 0xF2F2F7))
        case (.blueOrange, .expensive):
            PriceLevelColors(background: Color(hex: 0xFFD6B3), foreground: Color(hex: 0x8A3300))
        case (.monochrome, .cheap):
            // Inverted in dark mode, or the darkest chip would vanish on a dark background.
            PriceLevelColors(background: Color(light: 0x1C1C1E, dark: 0xF2F2F7), foreground: Color(light: 0xFFFFFF, dark: 0x1C1C1E))
        // Average is always the chip closest to the page, expensive a step further, cheap the strongest.
        case (.monochrome, .average):
            PriceLevelColors(background: Color(light: 0xE4E6EB, dark: 0x3A3A40), foreground: Color(light: 0x1C1C1E, dark: 0xF2F2F7))
        case (.monochrome, .expensive):
            PriceLevelColors(background: Color(light: 0x9CA3AF, dark: 0x6E6E76), foreground: Color(light: 0x1C1C1E, dark: 0xF2F2F7))
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: 1)
    }

    init(light: UInt32, dark: UInt32) {
        self.init(light: light, dark: dark, highLight: light, highDark: dark)
    }

    /// Light / dark pairs, with their Increase Contrast versions.
    init(light: UInt32, dark: UInt32, highLight: UInt32, highDark: UInt32) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            let isHigh = traits.accessibilityContrast == .high
            let hex = isHigh ? (isDark ? highDark : highLight) : (isDark ? dark : light)
            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        })
        #else
        self.init(hex: light)
        #endif
    }

    init(_ rgb: CustomColor) {
        self.init(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue, opacity: 1)
    }
}

extension CustomColor {
    /// Relative luminance check: light custom colours get a dark label so it stays readable.
    var prefersDarkLabel: Bool {
        func channel(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        let luminance = 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
        // Contrast against white (1.05 / (L + 0.05)) drops below 4.5:1 above ≈ 0.183.
        return luminance > 0.183
    }
}
