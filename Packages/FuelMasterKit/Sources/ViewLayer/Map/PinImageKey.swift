import DomainLayer
import SwiftUI
import ViewModelLayer

/// What a pin's image shows: pins with the same key share one image.
enum PinImageKey: Hashable {
    case price(Decimal, PriceLevel, Brand?, isHighlighted: Bool)
    case cluster(Int)
    case placeholder

    init(_ pin: StationPin, isHighlighted: Bool) {
        switch pin {
        case .station(let summary):
            self = .price(summary.price.amount, summary.level, summary.station.brand, isHighlighted: isHighlighted)
        case .cluster(_, let count, _): self = .cluster(count)
        case .placeholder: self = .placeholder
        }
    }
}
