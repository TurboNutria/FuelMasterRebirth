import Foundation

/// How a product is sold. Natural gas is priced per kilogram, everything else per litre.
public enum QuantityUnit: String, Sendable, Codable {
    case litre
    case kilogram
}

/// The products the app offers. Raw values are the ministry's `IDProducto`.
public enum Product: Int, CaseIterable, Sendable, Codable, Identifiable {
    case diesel = 4
    case dieselPremium = 5
    case petrol95E5 = 1
    case petrol95E10 = 23
    case petrol95Premium = 20
    case petrol98E5 = 3
    case petrol98E10 = 21
    case lpg = 17
    case cng = 18
    case lng = 19
    case renewableDiesel = 27
    case adBlue = 26

    public var id: Int { rawValue }

    public var unit: QuantityUnit {
        switch self {
        case .cng, .lng: .kilogram
        default: .litre
        }
    }

    /// AdBlue is sold at the pump but isn't a fuel, so it has no full-tank cost.
    public var isFuel: Bool { self != .adBlue }
}
