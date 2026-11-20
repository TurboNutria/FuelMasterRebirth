import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

extension PriceLevel {
    var emptyTitle: String {
        switch self {
        case .cheap: String(localized: "No hay gasolineras baratas aquí", bundle: .module)
        case .average: String(localized: "No hay gasolineras de precio medio aquí", bundle: .module)
        case .expensive: String(localized: "No hay gasolineras caras aquí", bundle: .module)
        }
    }
}
