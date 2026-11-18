import DomainLayer
import SwiftUI
import ViewModelLayer

/// The closed iPhone Duo in landscape ("tent"): too small for list and map side by side, so the
/// screen becomes a forecourt price sign (canvas: Tent Price Board). It shows the selected station,
/// or else the cheapest open one nearby. Laid out on the design's 880 × 440 grid and scaled to fit.
struct TentBoardScreen: View {
    @Environment(AppRouter.self) private var router
    @Environment(StationListViewModel.self) private var stationList
    @Environment(TentBoardViewModel.self) private var board
    @Environment(SettingsViewModel.self) private var settings

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / 880, proxy.size.height / 440)
            Group {
                if let content = board.content, content.station.id == stationID {
                    TentBoard(content: content, caption: caption(for: content), distance: distance,
                              nearestOpen: nearestOpenDistance, scale: scale)
                } else {
                    ProgressView().tint(.white)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .padding(8)
        .background(TentColors.background.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        // Gasolineras isn't on screen here, but its view model finds the nearby stations.
        .task { await stationList.start() }
        .task(id: TaskKey(station: stationID, product: settings.settings.product)) {
            guard let stationID else { return }
            await board.show(stationID, product: settings.settings.product, tankSize: settings.settings.tankSize)
        }
    }

    private struct TaskKey: Equatable {
        let station: StationID?
        let product: Product
    }

    private var rows: [StationListRow] { stationList.state.content?.rows ?? [] }

    /// The selected station, or the cheapest one that's open (the cheapest overall at night).
    private var stationID: StationID? {
        if let selected = router.selectedStationID { return selected }
        let open = rows.filter { $0.summary.openingStatus.isOpen }
        return (open.isEmpty ? rows : open).min { $0.summary.price.amount < $1.summary.price.amount }?.id
    }

    private func caption(for content: TentBoardContent) -> Text? {
        if router.selectedStationID == nil { return Text("Más barata cerca", bundle: .module) }
        return content.detail.isFavorite ? Text("Favorita", bundle: .module) : nil
    }

    private var distance: Double? {
        rows.first { $0.id == stationID }?.summary.distance ?? board.content?.detail.distance
    }

    private var nearestOpenDistance: Double? {
        rows.filter { $0.id != stationID && $0.summary.openingStatus.isOpen }
            .compactMap(\.summary.distance).min()
    }
}

enum TentColors {
    static let background = Color(hex: 0x141518)
    static let plate = Color(hex: 0xF4F1EA)
    static let ink = Color(hex: 0x141518)
    static let window = Color(hex: 0x050505)
    static let tile = Color(hex: 0x1D1F23)
    static let muted = Color(hex: 0xA9ACB2)
    static let open = Color(hex: 0x7FE0A3)
    static let closed = Color(hex: 0xFFA14A)
    static let priceLED = Color(hex: 0xFF3B2F)
    static let closedLED = Color(hex: 0xFFB000)
    static let down = Color(hex: 0x5CB8FF)
    static let up = Color(hex: 0xFFA14A)
}

/// The sign itself, at `scale` × the design's sizes.
struct TentBoard: View {
    let content: TentBoardContent
    let caption: Text?
    let distance: Double?
    let nearestOpen: Double?
    let scale: CGFloat

    @Environment(\.displayFormat) private var format

    var body: some View {
        VStack(spacing: 10 * scale) {
            header
            if content.isClosed {
                closedBody
            } else {
                ForEach(content.rows) { row in
                    TentPriceRow(row: row, scale: scale)
                }
            }
            Spacer(minLength: 0)
            footer
        }
        .padding(18 * scale)
        .frame(width: 880 * scale, height: 440 * scale)
        .background(TentColors.background, in: .rect(cornerRadius: 28 * scale))
        .foregroundStyle(Color(hex: 0xF2F2F2))
    }

    private var header: some View {
        HStack(spacing: 12 * scale) {
            Text(verbatim: "FM")
                .font(.board(18 * scale, .bold))
                .foregroundStyle(TentColors.ink)
                .frame(width: 36 * scale, height: 36 * scale)
                .background(TentColors.plate, in: .rect(cornerRadius: 8 * scale))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                if let caption {
                    caption
                        .font(.board(13 * scale, .semibold))
                        .textCase(.uppercase)
                        .kerning(1.8 * scale)
                        .foregroundStyle(TentColors.muted)
                }
                Text(content.station.name)
                    .font(.board(22 * scale, .semibold))
                    .lineLimit(1)
            }
            Spacer(minLength: 8 * scale)
            HStack(spacing: 18 * scale) {
                if let distance { Text(format.distance(meters: distance)) }
                status
            }
            .font(.board(20 * scale, .semibold))
        }
        .padding(.horizontal, 6 * scale)
        .frame(height: 40 * scale)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var status: some View {
        let label: Text? = switch content.detail.openingStatus {
        case .alwaysOpen: Text("Abierta 24 h", bundle: .module)
        case .open: content.hours.today == .allDay ? Text("Abierta 24 h", bundle: .module) : Text("Abierta", bundle: .module)
        case .closed: Text("Cerrada", bundle: .module)
        case .unknown: nil
        }
        if let label {
            let color = content.isClosed ? TentColors.closed : TentColors.open
            HStack(spacing: 8 * scale) {
                Circle().fill(color).frame(width: 10 * scale, height: 10 * scale)
                label.textCase(.uppercase)
            }
            .foregroundStyle(color)
        }
    }

    @ViewBuilder private var closedBody: some View {
        LEDWindow(scale: scale) {
            SevenSegmentText(text: "CErrAdA", unit: 10 * scale, color: TentColors.closedLED)
        }
        .frame(height: 170 * scale)
        .accessibilityLabel(Text("Cerrada", bundle: .module))
        if let opensAt = content.opensAt {
            HStack(spacing: 14 * scale) {
                VStack(alignment: .leading, spacing: 4 * scale) {
                    opensLabel(opensAt)
                        .font(.board(32 * scale, .bold))
                        .textCase(.uppercase)
                        .minimumScaleFactor(0.6)
                    if let nearestOpen {
                        Text("Más cercana abierta: \(format.distance(meters: nearestOpen))", bundle: .module)
                            .font(.board(18 * scale, .semibold))
                            .foregroundStyle(Color(hex: 0x4A4D53))
                    }
                }
                .lineLimit(1)
                .foregroundStyle(TentColors.ink)
                .padding(.horizontal, 22 * scale)
                .frame(width: 300 * scale, alignment: .leading)
                .frame(maxHeight: .infinity)
                .background(TentColors.plate, in: .rect(cornerRadius: 10 * scale))
                LEDWindow(scale: scale) {
                    SevenSegmentText(text: "AbrE \(Self.ledTime(opensAt))", unit: 7.5 * scale, color: TentColors.closedLED)
                }
                .accessibilityLabel(Text("Abre a las \(format.time(opensAt))", bundle: .module))
            }
            .frame(height: 132 * scale)
            .accessibilityElement(children: .combine)
        }
    }

    private func opensLabel(_ date: Date) -> Text {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = HoursText.stationTimeZone
        if calendar.isDateInToday(date) { return Text("Abre hoy", bundle: .module) }
        if calendar.isDateInTomorrow(date) { return Text("Abre mañana", bundle: .module) }
        var style = Date.FormatStyle(locale: format.locale).weekday(.wide)
        style.timeZone = HoursText.stationTimeZone
        return Text("Abre el \(date.formatted(style))", bundle: .module)
    }

    /// "06:00" in 24-hour time whatever the device setting: signs don't do am / pm.
    static func ledTime(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = HoursText.stationTimeZone
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    private var footer: some View {
        HStack {
            if let date = content.detail.freshness?.snapshotDate {
                Text("Actualizado \(format.time(date)) · Precios del Ministerio", bundle: .module)
            }
            Spacer()
            Text(verbatim: "FuelMaster")
        }
        .font(.board(15 * scale, .medium))
        .foregroundStyle(TentColors.muted)
        .padding(.horizontal, 6 * scale)
        .frame(height: 20 * scale)
    }
}

/// Fuel plate, LED price and the change since yesterday.
struct TentPriceRow: View {
    let row: TentBoardRow
    let scale: CGFloat

    @Environment(\.displayFormat) private var format

    var body: some View {
        HStack(spacing: 14 * scale) {
            HStack(spacing: 18 * scale) {
                FuelBadge(product: row.product, scale: scale)
                Text(row.product.displayName)
                    .font(.board(32 * scale, .bold))
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .foregroundStyle(TentColors.ink)
            .padding(.horizontal, 20 * scale)
            .frame(width: 300 * scale, alignment: .leading)
            .frame(maxHeight: .infinity)
            .background(TentColors.plate, in: .rect(cornerRadius: 10 * scale))

            LEDWindow(scale: scale) {
                HStack(alignment: .bottom, spacing: 14 * scale) {
                    SevenSegmentText(text: Self.signPrice(row.amount), unit: 10 * scale, color: TentColors.priceLED,
                                     smallLast: true)
                    Text(row.product.unit == .kilogram ? "€/kg" : "€/l")
                        .font(.board(20 * scale, .semibold))
                        .foregroundStyle(TentColors.muted)
                        .padding(.bottom, 4 * scale)
                }
            }

            changeTile
                .frame(width: 92 * scale)
                .frame(maxHeight: .infinity)
                .background(TentColors.tile, in: .rect(cornerRadius: 10 * scale))
        }
        .frame(height: 96 * scale)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(spokenText))
    }

    /// "1.459": always a point and three decimals, as signs show them.
    static func signPrice(_ amount: Decimal) -> String {
        String(format: "%.3f", NSDecimalNumber(decimal: amount).doubleValue)
    }

    @ViewBuilder private var changeTile: some View {
        VStack(spacing: 4 * scale) {
            if let change = row.change {
                Group {
                    switch change.direction {
                    case .down: Image(systemName: "arrowtriangle.down.fill").foregroundStyle(TentColors.down)
                    case .up: Image(systemName: "arrowtriangle.up.fill").foregroundStyle(TentColors.up)
                    case .same: Image(systemName: "minus").foregroundStyle(TentColors.muted)
                    }
                }
                .font(.system(size: 16 * scale, weight: .heavy))
                Text(cents(change))
                    .font(.board(18 * scale, .semibold))
                    .foregroundStyle(Color(hex: 0xD6D8DC))
            } else {
                Text(verbatim: "—")
                    .font(.board(18 * scale, .semibold))
                    .foregroundStyle(TentColors.muted)
            }
            Text("vs ayer", bundle: .module)
                .font(.board(12 * scale, .medium))
                .textCase(.uppercase)
                .kerning(1.2 * scale)
                .foregroundStyle(TentColors.muted)
        }
    }

    /// "−0,8": the change in cents, one decimal.
    private func cents(_ change: PriceChange) -> String {
        let value = NSDecimalNumber(decimal: change.difference * 100).doubleValue
        let number = abs(value).formatted(.number.precision(.fractionLength(1)).locale(format.locale))
        switch change.direction {
        case .down: return "−\(number)"
        case .up: return "+\(number)"
        case .same: return number
        }
    }

    private var spokenText: String {
        let name = String(localized: row.product.displayName)
        var text = "\(name): \(format.priceWithCurrency(row.amount))"
        if let change = row.change { text += ". " + ChangeLabel(change: change).spokenText }
        return text
    }
}

/// The black LED window with an inner shadow.
struct LEDWindow<Content: View>: View {
    let scale: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, 22 * scale)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .background(TentColors.window, in: .rect(cornerRadius: 10 * scale))
            .overlay {
                RoundedRectangle(cornerRadius: 10 * scale).strokeBorder(Color(hex: 0x26282D), lineWidth: 2 * scale)
            }
    }
}

/// The EU fuel label: B7 / XTL in a diamond for diesel, E5 / E10 in a circle for petrol, a square
/// for gas and AdBlue.
struct FuelBadge: View {
    let product: Product
    let scale: CGFloat

    var body: some View {
        let label = Text(verbatim: code).font(.board((code.count > 2 ? 14 : 19) * scale, .bold))
        switch shape {
        case .diamond:
            label
                .frame(width: 50 * scale, height: 50 * scale)
                .background {
                    Rectangle().strokeBorder(TentColors.ink, lineWidth: 3 * scale)
                        .frame(width: 38 * scale, height: 38 * scale)
                        .rotationEffect(.degrees(45))
                }
        case .circle:
            label
                .frame(width: 50 * scale, height: 50 * scale)
                .overlay { Circle().strokeBorder(TentColors.ink, lineWidth: 3 * scale) }
        case .square:
            label
                .frame(width: 50 * scale, height: 50 * scale)
                .overlay { RoundedRectangle(cornerRadius: 4 * scale).strokeBorder(TentColors.ink, lineWidth: 3 * scale) }
        }
    }

    private enum Shape { case diamond, circle, square }

    private var shape: Shape {
        switch product {
        case .diesel, .dieselPremium, .renewableDiesel: .diamond
        case .petrol95E5, .petrol95Premium, .petrol98E5: .circle
        case .lpg, .cng, .lng, .adBlue: .square
        }
    }

    private var code: String {
        switch product {
        case .diesel, .dieselPremium: "B7"
        case .renewableDiesel: "XTL"
        case .petrol95E5, .petrol95Premium, .petrol98E5: "E5"
        case .lpg: "LPG"
        case .cng: "CNG"
        case .lng: "LNG"
        case .adBlue: "AdB"
        }
    }
}

extension Font {
    /// Condensed, like the sign's Barlow Condensed (the system's condensed width stands in for it).
    static func board(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        .system(size: size, weight: weight).width(.condensed)
    }
}
