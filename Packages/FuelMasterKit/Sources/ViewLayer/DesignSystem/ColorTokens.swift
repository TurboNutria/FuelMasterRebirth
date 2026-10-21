import DomainLayer
import SwiftUI

/// Colour tokens from the design canvas (Fundamentos and Apariencia). Light / dark pairs.
public enum ColorTokens {
    public static let background = Color(light: 0xFAFAFA, dark: 0x171A27)
    public static let surface = Color(light: 0xFFFFFF, dark: 0x28283B)
    public static let cell = Color(light: 0xF2F2F2, dark: 0x494C5D)
    public static let separator = Color(light: 0xEFEFEF, dark: 0x40403F)
    /// Outline of unselected filter chips.
    public static let chipBorder = Color(light: 0xC9CCD3, dark: 0x5A5D6B)
    public static let textPrimary = Color(light: 0x1C1C1E, dark: 0xF2F2F7)
    public static let textSecondary = Color(light: 0x5B5F6B, dark: 0xA1A4B0)
    public static let open = Color(light: 0x1F7A3A, dark: 0x5BD07A)
    public static let closed = Color(light: 0x6B6F7A, dark: 0xA1A4B0)
    public static let offline = Color(hex: 0xC42B1C)
}

/// Accent presets: fill, label on the fill, and the tint used for text and icons on light surfaces.
public struct AccentColors: Sendable {
    public let fill: Color
    public let onFill: Color
    public let tint: Color

    public static func colors(for choice: AccentChoice) -> AccentColors {
        switch choice {
        case .preset(.orange): AccentColors(fill: Color(light: 0xF28C28, dark: 0xF59E45), onFill: Color(hex: 0x2B1300),
                                             tint: Color(light: 0xA84B00, dark: 0xF59E45))
        case .preset(.blue): AccentColors(fill: Color(hex: 0x0B63C4), onFill: .white, tint: Color(hex: 0x0B63C4))
        case .preset(.green): AccentColors(fill: Color(hex: 0x1E7B34), onFill: .white, tint: Color(hex: 0x1E7B34))
        case .preset(.purple): AccentColors(fill: Color(hex: 0x7C3AED), onFill: .white, tint: Color(hex: 0x7C3AED))
        case .preset(.pink): AccentColors(fill: Color(hex: 0xD6336C), onFill: .white, tint: Color(hex: 0xB8285A))
        case .preset(.graphite): AccentColors(fill: Color(hex: 0x4B5563), onFill: .white, tint: Color(hex: 0x4B5563))
        case .custom(let rgb):
            AccentColors(fill: Color(rgb), onFill: rgb.prefersDarkLabel ? Color(hex: 0x1C1C1E) : .white, tint: Color(rgb))
        }
    }
}

/// Chip colours per price level and scale: background, text, border.
public struct PriceLevelColors: Sendable {
    public let background: Color
    public let foreground: Color
    public let border: Color?

    public static func colors(for level: PriceLevel, scale: PriceScale) -> PriceLevelColors {
        switch (scale, level) {
        case (.trafficLight, .cheap):
            PriceLevelColors(background: Color(light: 0x1E7B34, dark: 0x4CC36B), foreground: Color(light: 0xFFFFFF, dark: 0x062B12), border: nil)
        case (.trafficLight, .average):
            PriceLevelColors(background: Color(hex: 0xFFF1B8), foreground: Color(hex: 0x5C4400), border: Color(hex: 0xE8C95A))
        case (.trafficLight, .expensive):
            PriceLevelColors(background: Color(hex: 0xEF5350), foreground: Color(hex: 0x2B0000), border: Color(hex: 0xD84340))
        case (.blueOrange, .cheap):
            PriceLevelColors(background: Color(hex: 0x0B63C4), foreground: .white, border: nil)
        case (.blueOrange, .average):
            PriceLevelColors(background: .white, foreground: Color(hex: 0x1C1C1E), border: Color(hex: 0xC9CCD3))
        case (.blueOrange, .expensive):
            PriceLevelColors(background: Color(hex: 0xFFE3CC), foreground: Color(hex: 0x8A3300), border: Color(hex: 0xF5A866))
        case (.monochrome, .cheap):
            PriceLevelColors(background: Color(hex: 0x1C1C1E), foreground: .white, border: nil)
        case (.monochrome, .average):
            PriceLevelColors(background: .white, foreground: Color(hex: 0x1C1C1E), border: Color(hex: 0x9CA3AF))
        case (.monochrome, .expensive):
            PriceLevelColors(background: Color(hex: 0xD1D5DB), foreground: Color(hex: 0x1C1C1E), border: Color(hex: 0x9CA3AF))
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: 1)
    }

    init(light: UInt32, dark: UInt32) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
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
