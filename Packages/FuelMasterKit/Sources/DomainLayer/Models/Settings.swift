import Foundation

public enum AccentPreset: String, CaseIterable, Sendable, Codable {
    case orange, blue, green, purple, pink, graphite
}

/// sRGB colour picked with the system colour picker, 0...1 per channel.
public struct CustomColor: Hashable, Sendable, Codable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

public enum AccentChoice: Hashable, Sendable, Codable {
    case preset(AccentPreset)
    case custom(CustomColor)
}

public enum PriceScale: String, CaseIterable, Sendable, Codable {
    /// Green / yellow / coral (default).
    case trafficLight
    /// Blue / white / orange, for red–green colour blindness.
    case blueOrange
    /// Lightness only.
    case monochrome
}

public enum Appearance: String, CaseIterable, Sendable, Codable {
    case system, light, dark
}

/// Per-device settings.
public struct Settings: Hashable, Sendable, Codable {
    public var product: Product
    /// In the product's unit (litres, or kilograms for natural gas).
    public var tankSize: Decimal
    public var accent: AccentChoice
    public var priceScale: PriceScale
    public var appearance: Appearance
    /// Used when location access is denied.
    public var defaultProvinceID: ProvinceID?
    public var lastViewedProvinceID: ProvinceID?
    public var onboardingCompleted: Bool

    public static let tankSizeRange: ClosedRange<Decimal> = 20...150

    public static let `default` = Settings(
        product: .diesel, tankSize: 55, accent: .preset(.orange), priceScale: .trafficLight,
        appearance: .system, defaultProvinceID: nil, lastViewedProvinceID: nil, onboardingCompleted: false
    )

    public init(product: Product, tankSize: Decimal, accent: AccentChoice, priceScale: PriceScale,
                appearance: Appearance, defaultProvinceID: ProvinceID?, lastViewedProvinceID: ProvinceID?,
                onboardingCompleted: Bool) {
        self.product = product
        self.tankSize = tankSize
        self.accent = accent
        self.priceScale = priceScale
        self.appearance = appearance
        self.defaultProvinceID = defaultProvinceID
        self.lastViewedProvinceID = lastViewedProvinceID
        self.onboardingCompleted = onboardingCompleted
    }
}
