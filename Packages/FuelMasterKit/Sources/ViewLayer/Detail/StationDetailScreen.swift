import Accessibility
import Charts
import DomainLayer
import SwiftUI
import ViewModelLayer

/// Where the detail is shown (Bear note 02): pushed in the tabs layout, a sheet side by side,
/// an inspector in split. Pushed screens get the system back button; the others a close button.
enum DetailPresentation {
    case push
    case sheet
    case inspector
}

/// Detalle de estación (canvas: "Detalle de estación" and the iPad inspector): name and hours,
/// the price against the area with the full-tank cost, the 7-day chart, other fuels, and
/// "Cómo llegar". Compartir and the favourite star sit in the toolbar.
struct StationDetailScreen: View {
    let viewModel: StationDetailViewModel
    let stationID: StationID
    let presentation: DetailPresentation

    @Environment(AppRouter.self) private var router
    @Environment(MapViewModel.self) private var map
    @Environment(\.displayFormat) private var format
    @Environment(\.accentColors) private var accent

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ColorTokens.background)
            .toolbar { toolbar }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarVisibility(presentation == .push ? .hidden : .automatic, for: .tabBar)
            #endif
            .task(id: stationID) { await viewModel.show(stationID) }
    }

    @ViewBuilder private var content: some View {
        switch viewModel.state {
        case .content(let content), .updating(let content), .offline(let content, _):
            ScrollView {
                DetailBody(content: content, compact: presentation == .inspector) {
                    Task { await viewModel.retryHistory() }
                }
                .frame(maxWidth: 672)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            #if os(iOS)
            // A compact button in the bottom bar rather than a full-width one over the content
            // (QA on the Duo, 2026-10-29). The inspector has no bar of its own: its item landed
            // on the window's, half over the map.
            .toolbar {
                if presentation != .inspector {
                    if showsMapButton {
                        ToolbarItem(placement: .bottomBar) { mapButton(content.station) }
                        ToolbarSpacer(.fixed, placement: .bottomBar)
                    }
                    ToolbarItem(placement: .bottomBar) { directionsButton(content.station) }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if presentation == .inspector {
                    GlassEffectContainer(spacing: 0) {
                        HStack(spacing: 12) {
                            if showsMapButton {
                                mapButton(content.station)
                                    .buttonStyle(.glass)
                                    .buttonBorderShape(.circle)
                            }
                            directionsButton(content.station)
                        }
                    }
                    .controlSize(.large)
                    .padding(.bottom, 12)
                }
            }
            #endif
        case .failed:
            EmptyStateView(systemImage: "fuelpump.slash",
                           title: String(localized: "No encontramos esta gasolinera", bundle: .module),
                           message: String(localized: "Puede que sus precios aún no se hayan cargado.", bundle: .module))
        case .firstLoad, .empty:
            ProgressView()
        }
    }

    /// Only when the detail came from a list: opened from a pin, the station is already on the map.
    /// A pushed detail always comes from a list (the map tab has no stack).
    private var showsMapButton: Bool {
        presentation == .push || router.detailOrigin == .list
    }

    private func mapButton(_ station: Station) -> some View {
        Button {
            map.focus(on: station.coordinate)
            router.showOnMap(station.id, keepsDetail: presentation == .inspector)
        } label: {
            // The bottom bar shows a Label as its icon alone, which is what this one wants.
            Label { Text("Ver en el mapa", bundle: .module) } icon: { Image(systemName: "map") }
                .labelStyle(.iconOnly)
                .font(.body.weight(.semibold))
                .foregroundStyle(accent.tint)
        }
        .accessibilityIdentifier("showOnMap")
        .accessibilityShowsLargeContentViewer()
    }

    private func directionsButton(_ station: Station) -> some View {
        Button {
            station.openDirections()
        } label: {
            // A plain stack: the bottom bar shows a Label as its icon alone.
            HStack(spacing: 8) {
                Image(systemName: "location.north.fill")
                Text("Cómo llegar", bundle: .module)
                    .accessibilityIdentifier("directions")
            }
                .font(.body.weight(.semibold))
                .foregroundStyle(accent.onFill)
                .padding(.horizontal, 8)
        }
        .buttonStyle(.glassProminent)
        .tint(accent.fill)
        // The bottom bar caps its text size; holding the button shows it large instead.
        .accessibilityShowsLargeContentViewer()
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        // A leading item in the inspector would land on the map's toolbar, so it closes from the
        // trailing group there; the sheet keeps the usual leading close button.
        if presentation == .sheet {
            ToolbarItem(placement: .cancellationAction) { closeButton }
        }
        if presentation == .inspector, viewModel.state.content == nil {
            ToolbarItem(placement: .primaryAction) { closeButton }
        }
        if let content = viewModel.state.content {
            ToolbarItemGroup(placement: .primaryAction) {
                if let url = viewModel.shareURL {
                    ShareLink(item: url, subject: Text(content.station.name), message: Text(shareMessage(content))) {
                        Label { Text("Compartir", bundle: .module) } icon: { Image(systemName: "square.and.arrow.up") }
                    }
                }
                Button {
                    Task { await viewModel.toggleFavorite() }
                } label: {
                    Label {
                        content.isFavorite ? Text("Quitar de favoritos", bundle: .module)
                            : Text("Añadir a favoritos", bundle: .module)
                    } icon: {
                        Image(systemName: content.isFavorite ? "star.fill" : "star")
                            .foregroundStyle(content.isFavorite ? accent.fill : ColorTokens.textPrimary)
                    }
                }
                .sensoryFeedback(.selection, trigger: content.isFavorite)
                if presentation == .inspector { closeButton }
            }
        }
    }

    private var closeButton: some View {
        Button {
            router.select(nil)
        } label: {
            Label { Text("Cerrar", bundle: .module) } icon: { Image(systemName: "xmark") }
        }
    }

    private func shareMessage(_ content: StationDetailContent) -> String {
        StationShare.message(content.station, price: content.detail.price, format: format)
    }
}

/// The scrolling part of the detail: open sections on the page, no cards. `compact` is the
/// narrower inspector, which drops the chart's axis labels and the stats.
struct DetailBody: View {
    let content: StationDetailContent
    let compact: Bool
    let onRetryHistory: () -> Void

    @Environment(\.displayFormat) private var format

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            DetailHeader(content: content)
            PriceCard(detail: content.detail, product: content.product)
            // Without a price here the chart would only show the area line.
            if let chart = content.chart, content.detail.price != nil {
                HistoryCard(chart: chart, provinceName: content.station.address.province, compact: compact,
                            onRetry: onRetryHistory)
            }
            if !content.detail.otherPrices.isEmpty {
                OtherPricesCard(prices: content.detail.otherPrices)
            }
            if let freshness = content.detail.freshness {
                Text("Actualizado \(format.relativeTimeInSentence(freshness.snapshotDate, now: .now))", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DetailHeader: View {
    let content: StationDetailContent

    @Environment(\.displayFormat) private var format

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                if let brand = content.station.brand {
                    BrandLogo(brand: brand, size: 40)
                }
                Text(content.station.name)
                    .font(.system(.title, design: .rounded, weight: .heavy))
                    .foregroundStyle(ColorTokens.textPrimary)
                    .accessibilityAddTraits(.isHeader)
            }
            .padding(.bottom, 4)
            Text(addressLine)
                .foregroundStyle(ColorTokens.textSecondary)
            HStack(spacing: 0) {
                HoursLabel(content.hours)
                if let distance = content.detail.distance {
                    // One run of text with the dot, as in the rows: a lone "·" fails the contrast check.
                    (Text(verbatim: " · ")
                        + Text("a \(format.distance(meters: distance))", bundle: .module, comment: "Distance inside a sentence: a 1,4 km"))
                        .monospacedDigit()
                }
            }
            .foregroundStyle(ColorTokens.textSecondary)
            // One sentence for VoiceOver, without the "·" read as its own item.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: hoursAndDistanceSpoken))
            .accessibilityAddTraits(.isStaticText)
        }
        .font(.subheadline)
    }

    /// «Abierta 24 horas, a 1,4 km».
    private var hoursAndDistanceSpoken: String {
        let hours = HoursLabel(content.hours).spokenText
        guard let distance = content.detail.distance else { return hours }
        return "\(hours), " + String(localized: "a \(format.distance(meters: distance))", bundle: .module,
                                     comment: "Distance inside a sentence: a 1,4 km")
    }

    private var addressLine: String {
        let address = content.station.address
        return "\(address.street) · \(address.postcode) \(address.locality)"
    }
}

/// The big price (the screen's one large figure), its gap to the average and the full-tank cost.
struct PriceCard: View {
    let detail: StationDetail
    let product: Product

    @Environment(\.displayFormat) private var format
    @Environment(\.priceScale) private var scale
    @Environment(\.dynamicTypeSize) private var typeSize
    /// 44 pt at the default size, as in Favoritos, growing with Dynamic Type.
    @ScaledMetric(relativeTo: .largeTitle) private var priceSize: CGFloat = 44

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let price = detail.price {
                VStack(alignment: .leading, spacing: 4) {
                    priceBlock(price)
                    gapLine
                }
                if let cost = detail.fuelCost {
                    RowSeparator()
                    tankRow(cost)
                }
            } else {
                Text("Esta gasolinera no vende \(String(localized: product.displayName))", bundle: .module)
                    .font(.callout)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func priceBlock(_ price: Price) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(price.product.displayName)
                .font(.subheadline)
                .foregroundStyle(ColorTokens.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(format.price(price.amount))
                    .font(.system(size: priceSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(priceColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(price.unit == .kilogram ? "€/kg" : "€/l")
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(ColorTokens.textSecondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(String(localized: price.product.displayName)), \(format.priceWithCurrency(price.amount))"
                                 + (detail.level.map { ", \($0.spokenName)" } ?? "")))
    }

    /// Cheap prices in their scale colour; the others in plain ink.
    private var priceColor: Color {
        detail.level == .cheap ? PriceLevelColors.colors(for: .cheap, scale: scale).background : ColorTokens.textPrimary
    }

    /// "↓ 0,012 bajo la media" in green, "↑ 0,004 sobre la media" in red: plain text, no pill.
    @ViewBuilder private var gapLine: some View {
        if let gap = detail.belowAverage {
            let amount = format.price(abs(gap))
            HStack(spacing: 4) {
                if gap != 0 { Image(systemName: gap > 0 ? "arrow.down" : "arrow.up").imageScale(.small) }
                if gap > 0 {
                    Text("\(amount) bajo la media", bundle: .module)
                } else if gap < 0 {
                    Text("\(amount) sobre la media", bundle: .module)
                } else {
                    Text("En la media", bundle: .module)
                }
            }
            .font(.subheadline.weight(.medium))
            .monospacedDigit()
            .foregroundStyle(gap > 0 ? ColorTokens.priceDown : gap < 0 ? ColorTokens.priceUp : ColorTokens.textSecondary)
        }
    }

    /// Label and amount on one line; stacked when they don't fit, so the amount never breaks.
    private func tankRow(_ cost: FuelCost) -> some View {
        let label = Text("Depósito lleno · \(format.quantity(cost.quantity, unit: cost.unit))", bundle: .module)
            .font(.subheadline)
            .foregroundStyle(ColorTokens.textPrimary)
        let amount = Text(format.money(cost.amount))
            .font(.system(.title3, design: .rounded, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(ColorTokens.textPrimary)
            .fixedSize()
        // Picked from the text size rather than ViewThatFits, which kept the one-line layout while
        // the text grew and clipped both (accessibility audit).
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        return layout {
            label.fixedSize(horizontal: false, vertical: true)
            if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
            amount
        }
        .accessibilityElement(children: .combine)
    }
}

/// "Últimos 7 días": the station's line in the accent, the dashed area average, and min / max / change.
struct HistoryCard: View {
    let chart: HistoryChart
    let provinceName: String
    let compact: Bool
    let onRetry: () -> Void

    @Environment(\.displayFormat) private var format
    @Environment(\.accentColors) private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Últimos 7 días", bundle: .module)
                    .font(.headline)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if chart.isLoading { ProgressView().controlSize(.small) }
            }
            chartView
                .frame(height: compact ? 100 : 160)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(chartSummary))
                .accessibilityChartDescriptor(audioGraph)
            legend
            if !compact { stats }
            if chart.isIncomplete && !chart.isLoading {
                HStack {
                    Text("Faltan días: no se pudo descargar el historial.", bundle: .module)
                        .font(.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                    Spacer(minLength: 8)
                    Button(String(localized: "Reintentar", bundle: .module), action: onRetry)
                        .font(.caption.weight(.semibold))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var stationPoints: [(day: Date, amount: Double)] { values(chart.history.points) }
    private var averagePoints: [(day: Date, amount: Double)] { values(chart.history.areaAverage) }

    private func values(_ points: [HistoryPoint]) -> [(day: Date, amount: Double)] {
        points.compactMap { point in point.amount.map { (point.day, NSDecimalNumber(decimal: $0).doubleValue) } }
    }

    private var chartView: some View {
        Chart {
            ForEach(stationPoints, id: \.day) { point in
                AreaMark(x: .value("Día", point.day, unit: .day),
                         yStart: .value("Precio", chart.range.lowerBound), yEnd: .value("Precio", point.amount),
                         series: .value("Serie", "station"))
                    .foregroundStyle(LinearGradient(colors: [accent.tint.opacity(0.18), accent.tint.opacity(0)],
                                                    startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Día", point.day, unit: .day), y: .value("Precio", point.amount),
                         series: .value("Serie", "station"))
                    .foregroundStyle(accent.tint)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }
            ForEach(averagePoints, id: \.day) { point in
                LineMark(x: .value("Día", point.day, unit: .day), y: .value("Precio", point.amount),
                         series: .value("Serie", "average"))
                    .foregroundStyle(ColorTokens.closed)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
            }
        }
        .chartYScale(domain: chart.range)
        .chartXAxis {
            if compact {
                AxisMarks { _ in }
            } else {
                AxisMarks(values: axisDays) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated).locale(format.locale))
                        .font(.caption2)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(ColorTokens.separator)
                if !compact, let amount = value.as(Double.self) {
                    AxisValueLabel(amount.formatted(.number.precision(.fractionLength(2)).locale(format.locale)))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            }
        }
    }

    /// First, middle and last day, as on the canvas ("14 oct · 17 oct · 20 oct").
    private var axisDays: [Date] {
        let days = chart.history.points.map(\.day)
        guard let first = days.first, let last = days.last else { return [] }
        return [first, days[days.count / 2], last]
    }

    private var legend: some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                Capsule().fill(accent.tint).frame(width: 16, height: 3)
                Text("Esta estación", bundle: .module)
            }
            HStack(spacing: 8) {
                Line().stroke(ColorTokens.closed, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])).frame(width: 16, height: 2)
                Text("Media de \(provinceName)", bundle: .module)
            }
        }
        .font(.caption)
        .foregroundStyle(ColorTokens.textSecondary)
        .accessibilityHidden(true)
    }

    private var stats: some View {
        Grid(alignment: .leading, horizontalSpacing: 8) {
            GridRow {
                stat(Text("Mínimo", bundle: .module), chart.minimum.map(format.price))
                stat(Text("Máximo", bundle: .module), chart.maximum.map(format.price))
                stat(Text("Hoy vs. hace 7 d", bundle: .module), changeText)
            }
        }
    }

    private func stat(_ title: Text, _ value: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            title.font(.caption).foregroundStyle(ColorTokens.textSecondary)
            Text(value ?? "—")
                .font(.subheadline.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(ColorTokens.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// "+0,010" / "−0,010" in the chips' format, or "Sin cambios".
    private var changeText: String? {
        guard let change = chart.change else { return nil }
        let amount = format.price(abs(change.difference))
        switch change.direction {
        case .up: return "+\(amount)"
        case .down: return "\u{2212}\(amount)"
        case .same: return String(localized: "Sin cambios", bundle: .module)
        }
    }

    /// «Últimos 7 días: entre 1,859 € y 1,879 €. Media de Madrid entre 1,923 € y 1,928 €.»
    /// Audio Graphs: VoiceOver can play the week as tones and step through each day.
    private var audioGraph: HistoryAudioGraph {
        HistoryAudioGraph(station: stationPoints, average: averagePoints, range: chart.range,
                          summary: chartSummary, averageName: String(localized: "Media de \(provinceName)", bundle: .module),
                          format: format)
    }

    private var chartSummary: String {
        var parts: [String] = []
        if let minimum = chart.minimum, let maximum = chart.maximum {
            parts.append(minimum == maximum
                ? String(localized: "Últimos 7 días: \(format.priceWithCurrency(minimum)) todos los días.", bundle: .module)
                : String(localized: "Últimos 7 días: entre \(format.priceWithCurrency(minimum)) y \(format.priceWithCurrency(maximum)).",
                         bundle: .module))
        }
        if let area = chart.areaRange {
            parts.append(String(localized: "Media de \(provinceName) entre \(format.priceWithCurrency(area.minimum)) y \(format.priceWithCurrency(area.maximum)).",
                                bundle: .module))
        }
        return parts.joined(separator: " ")
    }
}

/// The 7-day chart as data, for VoiceOver's Audio Graphs.
private struct HistoryAudioGraph: AXChartDescriptorRepresentable {
    let station: [(day: Date, amount: Double)]
    let average: [(day: Date, amount: Double)]
    let range: ClosedRange<Double>
    let summary: String
    let averageName: String
    let format: DisplayFormat

    func makeChartDescriptor() -> AXChartDescriptor {
        let days = Array(Set((station + average).map(\.day))).sorted()
        let xAxis = AXCategoricalDataAxisDescriptor(title: String(localized: "Día", bundle: .module),
                                                    categoryOrder: days.map(label))
        let yAxis = AXNumericDataAxisDescriptor(title: String(localized: "Precio", bundle: .module), range: range,
                                                gridlinePositions: []) { value in
            format.priceWithCurrency(Decimal(value))
        }
        let series = [
            AXDataSeriesDescriptor(name: String(localized: "Esta estación", bundle: .module), isContinuous: true,
                                   dataPoints: station.map { AXDataPoint(x: label($0.day), y: $0.amount) }),
            AXDataSeriesDescriptor(name: averageName, isContinuous: true,
                                   dataPoints: average.map { AXDataPoint(x: label($0.day), y: $0.amount) }),
        ]
        return AXChartDescriptor(title: String(localized: "Últimos 7 días", bundle: .module), summary: summary,
                                 xAxis: xAxis, yAxis: yAxis, additionalAxes: [], series: series)
    }

    private func label(_ day: Date) -> String {
        var style = Date.FormatStyle(date: .abbreviated, time: .omitted, locale: format.locale)
        style.timeZone = HoursText.stationTimeZone
        return day.formatted(style)
    }
}

/// A horizontal line for the dashed legend swatch.
private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
    }
}

/// The station's other products ("Diésel Premium 1,879"), as rows with hairlines.
struct OtherPricesCard: View {
    let prices: [Price]

    @Environment(\.displayFormat) private var format

    var body: some View {
        VStack(spacing: 0) {
            RowSeparator()
            ForEach(prices, id: \.product) { price in
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(price.product.displayName)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Spacer(minLength: 8)
                    Text(format.price(price.amount))
                        .fontWeight(.medium)
                        .monospacedDigit()
                        .foregroundStyle(ColorTokens.textPrimary)
                    if price.unit == .kilogram {
                        Text("€/kg").foregroundStyle(ColorTokens.textSecondary)
                    }
                }
                .font(.subheadline)
                .frame(minHeight: 48)
                .accessibilityElement(children: .combine)
                RowSeparator()
            }
        }
    }
}
