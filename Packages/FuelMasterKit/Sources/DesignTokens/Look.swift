import DomainLayer
import SwiftUI
import ViewModelLayer

/// The user's look settings, passed down the view tree of the app, the widgets and the watch.
/// RootView and WatchRootView set them from Settings.
extension EnvironmentValues {
    @Entry public var accentColors = AccentColors.colors(for: .preset(.orange))
    @Entry public var priceScale = PriceScale.trafficLight
    @Entry public var displayFormat = DisplayFormat()
}

extension Font {
    /// Prices on chips and rows (16 pt, rounded, bold).
    public static let price = Font.system(.callout, design: .rounded, weight: .bold)
}

extension Product {
    /// Name shown in the fuel picker, rows, widgets and VoiceOver.
    public var displayName: LocalizedStringResource {
        switch self {
        case .diesel: LocalizedStringResource("Diésel", bundle: .designTokens)
        case .dieselPremium: LocalizedStringResource("Diésel Premium", bundle: .designTokens)
        case .petrol95E5: LocalizedStringResource("Gasolina 95", bundle: .designTokens)
        case .petrol95Premium: LocalizedStringResource("Gasolina 95 Premium", bundle: .designTokens)
        case .petrol98E5: LocalizedStringResource("Gasolina 98", bundle: .designTokens)
        case .lpg: LocalizedStringResource("GLP", bundle: .designTokens)
        case .cng: LocalizedStringResource("GNC", bundle: .designTokens)
        case .lng: LocalizedStringResource("GNL", bundle: .designTokens)
        case .renewableDiesel: LocalizedStringResource("Diésel renovable (HVO)", bundle: .designTokens)
        case .adBlue: LocalizedStringResource("AdBlue", bundle: .designTokens)
        }
    }
}

extension QuantityUnit {
    /// "€/l" or "€/kg", after a price.
    public var pricePerUnit: LocalizedStringResource {
        switch self {
        case .litre: LocalizedStringResource("€/l", bundle: .designTokens, comment: "After a price per litre")
        case .kilogram: LocalizedStringResource("€/kg", bundle: .designTokens, comment: "After a price per kilogram")
        }
    }
}

extension PriceLevel {
    /// "barata" / "media" / "cara", lower case because it's read inside a sentence.
    public var spokenName: String {
        switch self {
        case .cheap: String(localized: "barata", bundle: .module, comment: "Price level, read inside a sentence")
        case .average: String(localized: "media", bundle: .module, comment: "Price level, read inside a sentence")
        case .expensive: String(localized: "cara", bundle: .module, comment: "Price level, read inside a sentence")
        }
    }
}

extension LocalizedStringResource.BundleDescription {
    /// This package target's bundle, which holds the shared String Catalog.
    static var designTokens: Self { .atURL(Bundle.module.bundleURL) }
}
