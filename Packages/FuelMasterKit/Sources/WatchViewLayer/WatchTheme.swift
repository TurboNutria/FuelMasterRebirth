#if os(watchOS)
import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

/// The look the watch draws with, set by WatchRootView from the iPhone's settings.
/// The accent, price scale and number format come from DesignTokens, shared with the iPhone.
extension EnvironmentValues {
    /// DEBUG screenshots: lists scroll to their last row once loaded.
    @Entry var scrollsToBottom = false
}

extension Product {
    /// The fuel's name on the watch: the iPhone's names, in this target's String Catalog.
    var watchName: String {
        switch self {
        case .diesel: String(localized: "Diésel", bundle: .module)
        case .dieselPremium: String(localized: "Diésel Premium", bundle: .module)
        case .petrol95E5: String(localized: "Gasolina 95", bundle: .module)
        case .petrol95Premium: String(localized: "Gasolina 95 Premium", bundle: .module)
        case .petrol98E5: String(localized: "Gasolina 98", bundle: .module)
        case .lpg: String(localized: "GLP", bundle: .module)
        case .cng: String(localized: "GNC", bundle: .module)
        case .lng: String(localized: "GNL", bundle: .module)
        case .renewableDiesel: String(localized: "Diésel renovable (HVO)", bundle: .module)
        case .adBlue: String(localized: "AdBlue", bundle: .module)
        }
    }
}

extension HoursSummary {
    var isClosed: Bool {
        if case .closed = status { return true }
        return false
    }

    /// "24 h", "7:30–22:00", "Cerrada hoy".
    var visibleText: String {
        switch today {
        case .allDay: String(localized: "24 h", bundle: .module, comment: "Open all day, short")
        case .ranges(let ranges): ranges
        case .closedAllDay: String(localized: "Cerrada hoy", bundle: .module)
        case .unknown(let raw): raw
        }
    }

    /// What VoiceOver reads instead of the range ("Cerrada, abre a las 7:30").
    var spokenText: String {
        switch status {
        case .alwaysOpen:
            return String(localized: "Abierta 24 horas", bundle: .module)
        case .open:
            if today == .allDay { return String(localized: "Abierta 24 horas", bundle: .module) }
            guard let nextChange else { return String(localized: "Abierta", bundle: .module) }
            return String(localized: "Abierta, cierra a las \(nextChange)", bundle: .module)
        case .closed:
            guard let nextChange else { return String(localized: "Cerrada", bundle: .module) }
            return String(localized: "Cerrada, abre a las \(nextChange)", bundle: .module)
        case .unknown:
            return String(localized: "Horario: \(visibleText)", bundle: .module)
        }
    }
}

extension Font {
    /// Large prices: the cheapest on Cerca and the detail's price. Scales with the text size.
    static let watchHeroPrice = Font.system(.largeTitle, design: .rounded, weight: .heavy)
    /// Price chips in rows.
    static let watchChip = Font.system(.body, design: .rounded, weight: .bold)
}
#endif
