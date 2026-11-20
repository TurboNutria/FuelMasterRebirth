#if os(watchOS)
import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

/// Cerca (canvas: Watch · Cerca): the cheapest station nearby in large type, then the next ones.
struct NearbyPage: View {
    let viewModel: StationListViewModel
    let onPickFuel: () -> Void

    /// The cheapest plus the next nine: enough to scroll with the crown, short enough to glance.
    static let rowLimit = 10

    @Environment(\.displayFormat) private var format
    @Environment(\.scrollsToBottom) private var scrollsToBottom

    var body: some View {
        ScrollViewReader { proxy in
            list
                .task(id: viewModel.state.content?.rows.count) {
                    guard scrollsToBottom, let last = viewModel.state.content?.rows.prefix(Self.rowLimit).last else { return }
                    try? await Task.sleep(for: .milliseconds(300))
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
        }
        .navigationTitle(Text("Cerca", bundle: .module))
        .task { await viewModel.start() }
    }

    private var list: some View {
        List {
            FuelButton(product: viewModel.product, action: onPickFuel)
                .listRowBackground(Color.clear)
            switch viewModel.state {
            case .firstLoad:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .accessibilityLabel(Text("Cargando precios", bundle: .module))
            case .content(let content), .updating(let content), .offline(let content, _):
                rows(content)
            case .empty(let reason):
                WatchMessage(systemImage: "fuelpump.slash", text: emptyText(reason))
                    .listRowBackground(Color.clear)
            case .failed(let error):
                WatchMessage(systemImage: error == .offline ? "wifi.slash" : "exclamationmark.icloud",
                             text: error == .offline
                                 ? String(localized: "Sin conexión", bundle: .module)
                                 : String(localized: "No se pudieron cargar los precios", bundle: .module))
                    .listRowBackground(Color.clear)
            }
        }
    }

    @ViewBuilder private func rows(_ content: StationListContent) -> some View {
        let staleAge = StaleAge.text(pricesDate: content.pricesDate, now: .now, format: format)
        if let cheapest = content.rows.first {
            NavigationLink(value: cheapest.id) {
                CheapestStation(row: cheapest, staleAge: staleAge)
            }
            .listRowBackground(Color.clear)
        }
        ForEach(content.rows.dropFirst().prefix(Self.rowLimit - 1)) { row in
            NavigationLink(value: row.id) {
                WatchStationRow(summary: row.summary, name: row.summary.station.name,
                                brand: row.summary.station.brand, hours: row.hours)
            }
            .opacity(staleAge == nil ? 1 : 0.55)
        }
    }

    private func emptyText(_ reason: EmptyReason) -> String {
        switch reason {
        case .noStationsNearby(let product, _):
            String(localized: "No hay gasolineras con \(product.watchName) cerca", bundle: .module)
        case .noStationsAtLevel, .noFavorites, .noSearchResults:
            String(localized: "No hay gasolineras con \(viewModel.product.watchName) cerca", bundle: .module)
        }
    }
}

/// The big price at the top of Cerca, with the station under it. Over an hour old, the price
/// dims and its age shows in red instead of the hours and distance.
struct CheapestStation: View {
    let row: StationListRow
    let staleAge: String?

    @Environment(\.priceScale) private var scale
    @Environment(\.displayFormat) private var format

    var body: some View {
        let summary = row.summary
        VStack(alignment: .leading, spacing: 6) {
            Text(format.price(summary.price.amount))
                .font(.watchHeroPrice)
                .monospacedDigit()
                .foregroundStyle(priceColor)
                .opacity(staleAge == nil ? 1 : 0.55)
            HStack(spacing: 8) {
                StationLogo(brand: summary.station.brand, size: 22)
                Text(summary.station.name)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let staleAge {
                StalePill(age: staleAge)
            } else {
                Text(verbatim: detailLine)
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(ColorTokens.textSecondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: spokenText))
    }

    /// Cheap prices take their level colour; others stay in plain ink, as on the iPhone detail.
    private var priceColor: Color {
        row.summary.level == .cheap ? PriceLevelColors.colors(for: .cheap, scale: scale).background
            : ColorTokens.textPrimary
    }

    /// "24 h · 1,4 km", or "Cerrada · 1,3 km".
    private var detailLine: String {
        let hours = row.hours.isClosed ? String(localized: "Cerrada", bundle: .module) : row.hours.visibleText
        guard let distance = row.summary.distance else { return hours }
        return "\(hours) · \(format.distance(meters: distance))"
    }

    private var spokenText: String {
        let summary = row.summary
        var parts = [summary.station.name,
                     "\(format.priceWithCurrency(summary.price.amount)), \(summary.level.spokenName)",
                     row.hours.spokenText]
        if let distance = summary.distance {
            parts.append(String(localized: "A \(format.distance(meters: distance))", bundle: .module,
                                comment: "Distance from you"))
        }
        if let staleAge { parts.append(staleAge) }
        return parts.joined(separator: ". ")
    }
}

/// Favoritas (canvas: Watch · Favoritas): the iPhone's favourites in its order, with the change
/// since yesterday when the price moved.
struct FavoritesPage: View {
    let viewModel: FavoritesViewModel
    let onPickFuel: () -> Void

    @Environment(\.scrollsToBottom) private var scrollsToBottom

    var body: some View {
        ScrollViewReader { proxy in
            list
                .task(id: viewModel.state.content?.rows.count) {
                    guard scrollsToBottom, let last = viewModel.state.content?.rows.last else { return }
                    try? await Task.sleep(for: .milliseconds(300))
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
        }
        .navigationTitle(Text("Favoritas", bundle: .module))
        .task { await viewModel.start() }
    }

    private var list: some View {
        List {
            switch viewModel.state {
            case .empty:
                WatchMessage(systemImage: "star", text: String(localized: "Aún no tienes favoritas", bundle: .module))
                    .listRowBackground(Color.clear)
            case .firstLoad:
                FuelButton(product: viewModel.product, action: onPickFuel)
                    .listRowBackground(Color.clear)
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            case .content(let content), .updating(let content), .offline(let content, _):
                FuelButton(product: viewModel.product, action: onPickFuel)
                    .listRowBackground(Color.clear)
                // A favourite whose province hasn't loaded yet joins once it has.
                ForEach(content.rows.filter { $0.item.station != nil }) { row in
                    NavigationLink(value: row.id) {
                        WatchStationRow(summary: row.summary, name: row.item.station?.name ?? "",
                                        brand: row.item.station?.brand, hours: row.hours,
                                        showsChange: true, change: row.change)
                    }
                }
            case .failed:
                FuelButton(product: viewModel.product, action: onPickFuel)
                    .listRowBackground(Color.clear)
            }
        }
    }
}

/// The fuels with a station nearby, the chosen one ticked (canvas: Watch · Combustible).
struct FuelPicker: View {
    let products: [Product]
    let chosen: Product
    let onSelect: (Product) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accentColors) private var accent

    var body: some View {
        List(products) { product in
            Button {
                onSelect(product)
                dismiss()
            } label: {
                HStack {
                    Text(product.watchName)
                        .fontWeight(product == chosen ? .semibold : .regular)
                    Spacer()
                    if product == chosen {
                        Image(systemName: "checkmark")
                            .bold()
                            .foregroundStyle(accent.tint)
                    }
                }
            }
            .accessibilityAddTraits(product == chosen ? .isSelected : [])
        }
        .navigationTitle(Text("Combustible", bundle: .module))
    }
}
#endif
