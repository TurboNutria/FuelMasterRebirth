import Foundation

/// How a product is sold. Natural gas is priced per kilogram, everything else per litre.
public enum QuantityUnit: String, Sendable, Codable {
    case litre
    case kilogram
}

/// The products the app offers. Raw values are the ministry's `IDProducto`.
///
/// Gasolina 95 and 98 each cover their E5 and E10 blends: a driver looks for "95", and E10 is sold
/// at a handful of stations. A station's price is its E5 one, or its E10 one if that's all it sells.
public enum Product: Int, CaseIterable, Sendable, Codable, Identifiable {
    case diesel = 4
    case dieselPremium = 5
    case petrol95E5 = 1
    case petrol95Premium = 20
    case petrol98E5 = 3
    case lpg = 17
    case cng = 18
    case lng = 19
    case renewableDiesel = 27
    case adBlue = 26

    public var id: Int { rawValue }

    /// The E10 blends were separate products once; anything saved with them reads as 95 or 98.
    public init?(storedID: Int) {
        switch storedID {
        case 23: self = .petrol95E5
        case 21: self = .petrol98E5
        default: self.init(rawValue: storedID)
        }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let id = try container.decode(Int.self)
        guard let product = Product(storedID: id) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown product \(id)")
        }
        self = product
    }

    public var unit: QuantityUnit {
        switch self {
        case .cng, .lng: .kilogram
        default: .litre
        }
    }

    /// What a fuel menu lists: the products with a station to show, plus the chosen
    /// one so it never vanishes from its own menu. Everything while nothing is loaded.
    public static func offered(from available: Set<Product>, chosen: Product) -> [Product] {
        guard !available.isEmpty else { return allCases }
        return allCases.filter { available.contains($0) || $0 == chosen }
    }

    /// AdBlue is sold at the pump but isn't a fuel, so it has no full-tank cost.
    public var isFuel: Bool { self != .adBlue }
}
