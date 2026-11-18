#if os(iOS)
import DomainLayer
import SwiftUI
import ViewModelLayer
import WidgetKit

// The widgets (canvas: "Widgets · pantalla de inicio" and "transparente, tintado y bloqueo").
// The extension only supplies timelines; everything drawn lives here, next to the design system.

/// Names in the widget gallery.
public enum WidgetNames {
    public static let cheapest = LocalizedStringResource("Más barata cerca", bundle: .viewLayer)
    public static let favorites = LocalizedStringResource("Favoritos", bundle: .viewLayer)
}

// MARK: - Home Screen: small, the cheapest nearby

public struct CheapestWidgetView: View {
    let content: WidgetContent

    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.displayFormat) private var format

    public init(content: WidgetContent) {
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "fuelpump.fill")
                    .foregroundStyle(accent.tint)
                    .widgetAccentable()
                Text(content.product.displayName)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let distance = content.cheapest?.distance { Text(distance).lineLimit(1) }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(ColorTokens.textSecondary)

            Spacer(minLength: 6)

            if let station = content.cheapest {
                VStack(alignment: .leading, spacing: 4) {
                    WidgetPrice(station: station, scale: content.priceScale, isStale: content.staleAge != nil,
                                size: 40)
                    if content.staleAge == nil {
                        if renderingMode == .fullColor {
                            GapLine(belowAverage: station.belowAverage)
                        } else {
                            LevelTag(level: station.level)
                        }
                    }
                }
                Spacer(minLength: 6)
                HStack(spacing: 6) {
                    WidgetLogo(brand: station.brand, size: 20)
                    Text(station.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(ColorTokens.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                if let age = content.staleAge {
                    StaleTag(age: age).padding(.top, 6)
                }
            } else {
                Text("---")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(ColorTokens.textSecondary)
                Spacer(minLength: 6)
                Text("Sin precios", bundle: .module)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(ColorTokens.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) { ColorTokens.surface }
        .widgetURL(content.cheapest?.link)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenText)
    }

    private var accent: AccentColors { AccentColors.colors(for: content.accent) }

    /// «Ballenoil. Diésel, 1,859 €, barata. A 1,4 km.» plus the age when it's old.
    private var spokenText: String {
        let product = String(localized: content.product.displayName)
        guard let station = content.cheapest else {
            return "\(product). " + String(localized: "Sin precios", bundle: .module)
        }
        var parts = ["\(station.name). \(product), \(format.priceWithCurrency(station.price)), \(station.level.spokenName)."]
        if let distance = station.distance { parts.append(distance) }
        if let age = content.staleAge { parts.append(age) }
        return parts.joined(separator: " ")
    }
}

// MARK: - Home Screen: medium, the favourites

public struct FavoritesWidgetView: View {
    let content: WidgetContent

    @Environment(\.widgetRenderingMode) private var renderingMode

    public init(content: WidgetContent) {
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .foregroundStyle(AccentColors.colors(for: content.accent).tint)
                    .widgetAccentable()
                Text("Favoritos", bundle: .module)
                Text(verbatim: "·")
                Text(content.product.displayName).lineLimit(1)
                Spacer(minLength: 4)
                if let age = content.favoritesStaleAge { StaleTag(age: age) }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(ColorTokens.textSecondary)

            if content.favorites.isEmpty {
                Text("Aún no tienes favoritas", bundle: .module)
                    .font(.subheadline)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 8) {
                    ForEach(content.favorites.prefix(3)) { station in
                        Link(destination: station.link) {
                            FavoriteWidgetRow(station: station, isStale: content.favoritesStaleAge != nil,
                                              accented: renderingMode != .fullColor)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) { ColorTokens.surface }
        .environment(\.priceScale, content.priceScale)
    }
}

private struct FavoriteWidgetRow: View {
    let station: WidgetStation
    let isStale: Bool
    let accented: Bool

    @Environment(\.displayFormat) private var format

    var body: some View {
        HStack(spacing: 8) {
            WidgetLogo(brand: station.brand, size: 22)
            HStack(spacing: 4) {
                Text(station.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ColorTokens.textPrimary)
                if let distance = station.distance {
                    Text(verbatim: "· \(distance)")
                        .font(.subheadline)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .layoutPriority(1)
                }
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            if accented {
                if station.level != .average { LevelTag(level: station.level) }
                Text(format.price(station.price))
                    .font(.system(.callout, design: .rounded, weight: .heavy))
                    .monospacedDigit()
                    .widgetAccentable()
            } else {
                if let change = station.change, change.direction != .same { ChangeLabel(change: change) }
                PriceChip(amount: station.price, level: station.level)
            }
        }
        .opacity(isStale ? 0.55 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(station.name), \(format.priceWithCurrency(station.price)), \(station.level.spokenName)"))
    }
}

// MARK: - Lock Screen

/// «⛽ 1,859 € · Ballenoil»
public struct InlineWidgetView: View {
    let content: WidgetContent

    @Environment(\.displayFormat) private var format

    public init(content: WidgetContent) {
        self.content = content
    }

    public var body: some View {
        Group {
            if let station = content.cheapest {
                Label {
                    Text(verbatim: "\(format.priceWithCurrency(station.price)) · \(station.name)")
                } icon: {
                    Image(systemName: "fuelpump")
                }
            } else {
                Label { Text("Sin precios", bundle: .module) } icon: { Image(systemName: "fuelpump") }
            }
        }
        .widgetURL(content.cheapest?.link)
        .containerBackground(for: .widget) { Color.clear }
    }
}

/// A gauge: the arc shows where the cheapest price falls between the area's cheapest and dearest.
public struct CircularWidgetView: View {
    let content: WidgetContent

    @Environment(\.displayFormat) private var format

    public init(content: WidgetContent) {
        self.content = content
    }

    public var body: some View {
        Gauge(value: content.gaugeFraction ?? 0) {
            Image(systemName: "fuelpump.fill")
        } currentValueLabel: {
            Text(content.cheapest.map { shortPrice($0.price) } ?? "--")
                .font(.system(.body, design: .rounded, weight: .heavy))
                .minimumScaleFactor(0.6)
        }
        .gaugeStyle(.accessoryCircular)
        .opacity(content.staleAge == nil ? 1 : 0.55)
        .widgetURL(content.cheapest?.link)
        .containerBackground(for: .widget) { AccessoryWidgetBackground() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: content.cheapest.map {
            "\($0.name), \(format.priceWithCurrency($0.price)), \($0.level.spokenName)"
        } ?? String(localized: "Sin precios", bundle: .module)))
    }

    /// "1,86": two decimals so it fits inside the ring.
    private func shortPrice(_ amount: Decimal) -> String {
        amount.formatted(.number.precision(.fractionLength(2)).locale(format.locale))
    }
}

/// «Ballenoil · 1,4 km / 1,859 € / ↓ 0,065 bajo la media»
public struct RectangularWidgetView: View {
    let content: WidgetContent

    @Environment(\.displayFormat) private var format

    public init(content: WidgetContent) {
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let station = content.cheapest {
                Text(verbatim: [station.name, station.distance].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(format.priceWithCurrency(station.price))
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .monospacedDigit()
                    .widgetAccentable()
                    .opacity(content.staleAge == nil ? 1 : 0.55)
                if let age = content.staleAge {
                    Label { Text(age) } icon: { Image(systemName: "clock") }
                        .font(.caption2.weight(.semibold))
                } else {
                    GapLine(belowAverage: station.belowAverage, colored: false)
                        .font(.caption2.weight(.medium))
                }
            } else {
                Text(content.product.displayName).font(.caption.weight(.semibold))
                Text("Sin precios", bundle: .module).font(.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(content.cheapest?.link)
        .containerBackground(for: .widget) { Color.clear }
    }
}

// MARK: - Pieces

/// The big price: the cheap colour of the user's scale, plain ink otherwise (as on the detail),
/// dimmed when the prices are over an hour old.
private struct WidgetPrice: View {
    let station: WidgetStation
    let scale: PriceScale
    let isStale: Bool
    let size: CGFloat

    @Environment(\.displayFormat) private var format
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        Text(format.price(station.price))
            .font(.system(size: size, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .foregroundStyle(color)
            .widgetAccentable()
            .opacity(isStale ? 0.55 : 1)
    }

    private var color: Color {
        guard renderingMode == .fullColor, station.level == .cheap else { return ColorTokens.textPrimary }
        return PriceLevelColors.colors(for: .cheap, scale: scale).background
    }
}

/// "↓ 0,065 bajo la media", as under the detail's price.
private struct GapLine: View {
    let belowAverage: Decimal?
    var colored = true

    @Environment(\.displayFormat) private var format

    var body: some View {
        if let gap = belowAverage {
            let amount = format.price(abs(gap))
            HStack(spacing: 2) {
                if gap != 0 { Image(systemName: gap > 0 ? "arrow.down" : "arrow.up").imageScale(.small) }
                if gap > 0 {
                    Text("\(amount) bajo la media", bundle: .module)
                } else if gap < 0 {
                    Text("\(amount) sobre la media", bundle: .module)
                } else {
                    Text("En la media", bundle: .module)
                }
            }
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(colored ? color(gap) : Color.primary)
        }
    }

    private func color(_ gap: Decimal) -> Color {
        gap > 0 ? ColorTokens.priceDown : gap < 0 ? ColorTokens.priceUp : ColorTokens.textSecondary
    }
}

/// "↓ Barata" / "↑ Cara" in an outline: in tinted and clear widgets colour is gone, so the
/// level needs words. Average prices carry nothing.
private struct LevelTag: View {
    let level: PriceLevel

    var body: some View {
        if let text {
            text
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .overlay(Capsule().stroke(lineWidth: 1.5))
                .widgetAccentable()
        }
    }

    private var text: Text? {
        switch level {
        case .cheap: Text("↓ Barata", bundle: .module)
        case .expensive: Text("↑ Cara", bundle: .module)
        case .average: nil
        }
    }
}

/// "Hace 3 h" in red: the prices haven't been updated for over an hour.
private struct StaleTag: View {
    let age: String

    var body: some View {
        Label { Text(age) } icon: { Image(systemName: "clock") }
            .labelStyle(.titleAndIcon)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(ColorTokens.offline, in: .capsule)
            .fixedSize()
    }
}

/// The chain's logo, or the grey pump. Kept in its own colours in tinted widgets, where a
/// tinted white disc would turn into a blank circle.
private struct WidgetLogo: View {
    let brand: Brand?
    let size: CGFloat

    var body: some View {
        if let brand {
            Image("brand-\(brand.rawValue)", bundle: .module)
                .resizable()
                .interpolation(.high)
                .widgetAccentedRenderingMode(.desaturated)
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(.circle)
                .accessibilityHidden(true)
        } else {
            StationLogo(brand: nil, size: size)
        }
    }
}

#endif
