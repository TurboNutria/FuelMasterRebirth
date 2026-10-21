import DomainLayer
import SwiftUI
import ViewModelLayer

/// A price pin on the map (canvas: "Mapa de gasolineras"). The cheapest nearby station gets the
/// large pin with a white border, an arrow and a tail; the rest are small chips, and stations whose
/// chips would overlap become a circle with their count.
struct MapPinView: View {
    let pin: StationPin
    let isHighlighted: Bool

    @Environment(\.priceScale) private var scale
    @Environment(\.displayFormat) private var format
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch pin {
            case .station(let summary):
                if isHighlighted {
                    highlighted(summary)
                } else {
                    small(amount: summary.price.amount, level: summary.level)
                }
            case .cluster(_, let count, _):
                clusterCircle(count)
            case .placeholder:
                small(amount: nil, level: nil)
            }
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.3), value: isHighlighted)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
    }

    private func small(amount: Decimal?, level: PriceLevel?) -> some View {
        PriceChip(amount: amount, level: level, size: .small)
            .shadow(color: .black.opacity(0.14), radius: 3, y: 2)
    }

    private func highlighted(_ summary: StationSummary) -> some View {
        let colors = PriceLevelColors.colors(for: summary.level, scale: scale)
        return VStack(spacing: 0) {
            HStack(spacing: 4) {
                if summary.level == .cheap { Image(systemName: "arrow.down").font(.caption.weight(.heavy)) }
                Text(format.price(summary.price.amount))
                    .font(.system(.callout, design: .rounded, weight: .heavy))
                    .monospacedDigit()
            }
            .foregroundStyle(colors.foreground)
            .padding(.vertical, 6)
            .padding(.horizontal, 11)
            .background(colors.background, in: .capsule)
            .overlay { Capsule().strokeBorder(.white, lineWidth: 2) }
            .shadow(color: colors.background.opacity(0.4), radius: 6, y: 4)
            PinTail()
                .fill(colors.background)
                .frame(width: 14, height: 8)
        }
    }

    /// A group of stations: a dark circle with how many there are, growing a little with the count.
    private func clusterCircle(_ count: Int) -> some View {
        let diameter: CGFloat = count < 10 ? 34 : count < 100 ? 40 : 46
        return Text(count, format: .number)
            .font(.system(.subheadline, design: .rounded, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .frame(width: diameter, height: diameter)
            .background(Color(hex: 0x1C1C1E).opacity(0.88), in: .circle)
            .overlay { Circle().strokeBorder(.white, lineWidth: 2) }
            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
    }

    /// «Ballenoil, 1,859 euros, barata.» / «6 gasolineras, desde 1,879 euros» / «Precio cargando».
    private var accessibilityText: String {
        switch pin {
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
