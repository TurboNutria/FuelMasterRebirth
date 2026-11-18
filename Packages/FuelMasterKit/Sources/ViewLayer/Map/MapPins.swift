import DomainLayer
import SwiftUI
import ViewModelLayer

/// A price pin on the map (canvas: "Mapa de gasolineras"). The station whose detail is open gets the
/// large pin with a tail; the rest are small chips, and stations whose
/// chips would overlap become a circle with their count. `PinMap` draws it once per look into
/// an image, so nothing here may depend on state.
struct MapPinView: View {
    let pin: StationPin
    let isHighlighted: Bool

    @Environment(\.priceScale) private var scale
    @Environment(\.displayFormat) private var format

    var body: some View {
        switch pin {
        case .station(let summary):
            if isHighlighted {
                highlighted(summary)
            } else {
                small(amount: summary.price.amount, level: summary.level, brand: summary.station.brand)
            }
        case .cluster(_, let count, _):
            clusterCircle(count)
        case .placeholder:
            small(amount: nil, level: nil, brand: nil)
        }
    }

    private func small(amount: Decimal?, level: PriceLevel?, brand: Brand?) -> some View {
        PriceChip(amount: amount, level: level, size: .small, brand: brand)
            .shadow(color: .black.opacity(0.14), radius: 3, y: 2)
    }

    private func highlighted(_ summary: StationSummary) -> some View {
        let colors = PriceLevelColors.colors(for: summary.level, scale: scale)
        return VStack(spacing: 0) {
            HStack(spacing: 4) {
                if let brand = summary.station.brand {
                    BrandLogo(brand: brand, size: 24).padding(.leading, -8).padding(.trailing, 2)
                }
                if summary.level == .cheap { Image(systemName: "arrow.down").font(.caption.weight(.heavy)) }
                Text(format.price(summary.price.amount))
                    .font(.system(.callout, design: .rounded, weight: .bold))
                    .monospacedDigit()
            }
            .foregroundStyle(colors.foreground)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(colors.background, in: .capsule)
            PinTail()
                .fill(colors.background)
                .frame(width: 14, height: 8)
        }
        // Its size and tail mark it; a neutral shadow lifts it off the map.
        .compositingGroup()
        .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
    }

    /// A group of stations: a circle with how many there are, growing a little with the count. It
    /// takes the text colour, dark on the light map and light on the dark one, so it needs no ring.
    private func clusterCircle(_ count: Int) -> some View {
        let diameter: CGFloat = count < 10 ? 32 : count < 100 ? 40 : 48
        return Text(count, format: .number)
            .font(.system(.subheadline, design: .rounded, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(ColorTokens.background)
            .frame(width: diameter, height: diameter)
            .background(ColorTokens.textPrimary, in: .circle)
            .shadow(color: .black.opacity(0.14), radius: 3, y: 2)
    }
}

/// The small downward triangle under the highlighted pin.
struct PinTail: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

extension StationPin {
    /// «Ballenoil, 1,859 euros, barata.» / «6 gasolineras, desde 1,879 euros» / «Precio cargando».
    func accessibilityText(format: DisplayFormat) -> String {
        switch self {
        case .station(let summary):
            return String(localized: "\(summary.station.name), \(format.priceWithCurrency(summary.price.amount)), \(summary.level.spokenName)",
                          bundle: .module, comment: "Row: product, price, level")
        case .cluster(let cheapest, let count, _):
            return String(localized: "\(count) gasolineras, desde \(format.priceWithCurrency(cheapest.price.amount))", bundle: .module)
        case .placeholder:
            return String(localized: "Precio cargando", bundle: .module)
        }
    }
}
