import DomainLayer
import SwiftUI
import ViewModelLayer

/// The user's look settings, passed down the view tree. RootView sets them from Settings (U6).
extension EnvironmentValues {
    @Entry public var accentColors = AccentColors.colors(for: .preset(.orange))
    @Entry public var priceScale = PriceScale.trafficLight
    @Entry public var displayFormat = DisplayFormat()
}

/// Type styles from the canvas "Fundamentos". Everything scales with Dynamic Type.
extension Font {
    /// Screen titles: "Gasolineras" (34 pt, rounded, heavy).
    static let screenTitle = Font.system(.largeTitle, design: .rounded, weight: .heavy)
    /// Prices on chips and rows (16 pt, rounded, bold).
    static let price = Font.system(.callout, design: .rounded, weight: .bold)
    static let rowTitle = Font.system(.callout, weight: .semibold)
    static let rowDetail = Font.footnote
}

extension Product {
    /// Name shown in the fuel picker, rows and VoiceOver.
    public var displayName: LocalizedStringResource {
        switch self {
        case .diesel: LocalizedStringResource("Diésel", bundle: .viewLayer)
        case .dieselPremium: LocalizedStringResource("Diésel Premium", bundle: .viewLayer)
        case .petrol95E5: LocalizedStringResource("Gasolina 95", bundle: .viewLayer)
        case .petrol95E10: LocalizedStringResource("Gasolina 95 E10", bundle: .viewLayer)
        case .petrol95Premium: LocalizedStringResource("Gasolina 95 Premium", bundle: .viewLayer)
        case .petrol98E5: LocalizedStringResource("Gasolina 98", bundle: .viewLayer)
        case .petrol98E10: LocalizedStringResource("Gasolina 98 E10", bundle: .viewLayer)
        case .lpg: LocalizedStringResource("GLP", bundle: .viewLayer)
        case .cng: LocalizedStringResource("GNC", bundle: .viewLayer)
        case .lng: LocalizedStringResource("GNL", bundle: .viewLayer)
        case .renewableDiesel: LocalizedStringResource("Diésel renovable (HVO)", bundle: .viewLayer)
        case .adBlue: LocalizedStringResource("AdBlue", bundle: .viewLayer)
        }
    }
}

extension LocalizedStringResource.BundleDescription {
    /// This package target's bundle, which holds the View layer's String Catalog.
    static var viewLayer: Self { .atURL(Bundle.module.bundleURL) }
}

extension PriceLevel {
    /// "barata" / "media" / "cara", lower case because it's read inside a sentence.
    var spokenName: String {
        switch self {
        case .cheap: String(localized: "barata", bundle: .module, comment: "Price level, read inside a sentence")
        case .average: String(localized: "media", bundle: .module, comment: "Price level, read inside a sentence")
        case .expensive: String(localized: "cara", bundle: .module, comment: "Price level, read inside a sentence")
        }
    }
}
