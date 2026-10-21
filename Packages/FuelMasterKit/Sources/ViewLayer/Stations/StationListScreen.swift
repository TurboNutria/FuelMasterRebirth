import DomainLayer
import SwiftUI
import ViewModelLayer

/// Gasolineras (canvas: "Lista de gasolineras" and its states). Reads the view model and sends
/// intents back; the view model lives above the layouts, so nothing resets when they swap.
public struct StationListScreen: View {
    @Bindable var viewModel: StationListViewModel

    @Environment(AppRouter.self) private var router
    @Environment(\.displayFormat) private var format
    @Environment(\.dynamicTypeSize) private var typeSize

    public init(viewModel: StationListViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if typeSize.isAccessibilitySize {
                        // Canvas "Texto muy grande": title alone, then the fuel and one filters button.
                        title
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 12) { fuelMenu; CompactFilters(viewModel: viewModel) }
                            VStack(alignment: .leading, spacing: 12) { fuelMenu; CompactFilters(viewModel: viewModel) }
                        }
                    } else {
                        HStack(alignment: .lastTextBaseline) {
                            title
                            Spacer(minLength: 8)
                            fuelMenu
                        }
                        SortPicker(sort: $viewModel.sort)
                        LevelChips(selection: $viewModel.levelFilter)
                    }
                    ListHeader(viewModel: viewModel)
                    content
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 96)
            }
            .background(ColorTokens.background)
            .refreshable { await viewModel.refresh(force: true) }
            .overlay(alignment: .bottom) { pills }
            #if os(iOS)
            .toolbarVisibility(.hidden, for: .navigationBar)
            #endif
        }
        .task { await viewModel.start() }
        .onChange(of: viewModel.state.content?.rows.count) { old, new in
            // «23 gasolineras cargadas», once the first load lands.
            if old == nil, let new {
                AccessibilityNotification.Announcement(
                    String(localized: "\(new) gasolineras cargadas", bundle: .module)).post()
            }
        }
    }

    private var title: some View {
        Text("Gasolineras", bundle: .module)
            .font(.screenTitle)
            .foregroundStyle(ColorTokens.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .accessibilityAddTraits(.isHeader)
            .padding(.top, 8)
    }

    private var fuelMenu: some View {
        FuelMenu(product: viewModel.product) { product in
            Task { await viewModel.select(product) }
        }
    }

    @ViewBuilder private var content: some View {
        switch viewModel.state {
        case .firstLoad:
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .padding(.top, 120)
                .accessibilityLabel(Text("Cargando gasolineras", bundle: .module))
        case .content(let content), .updating(let content), .offline(let content, _):
            StationCard(rows: content.rows) { router.select($0) }
        case .empty(let reason):
            EmptyListView(reason: reason, showsMapAction: router.layoutMode.hasMapTab,
                          onShowMap: { router.selectedTab = .map },
                          onShowAll: { viewModel.levelFilter = .all })
                .padding(.top, 60)
        case .failed(let error):
            FailedListView(error: error) {
                Task { await viewModel.refresh(force: true) }
            }
            .padding(.top, 60)
        }
    }

    private var pills: some View {
        VStack(spacing: 10) {
            if case .updating = viewModel.state {
                UpdatingPill()
            }
            if viewModel.isOfflinePillVisible {
                OfflinePill(age: viewModel.pricesDate.map { format.relativeTimeInSentence($0, now: .now) }) {
                    viewModel.dismissOfflinePill()
                }
            }
        }
        .padding(.bottom, 12)
        .animation(.default, value: viewModel.isOfflinePillVisible)
    }
}

// MARK: - Pieces

/// "Diésel ⌄": the fuel picker as a glass capsule menu.
struct FuelMenu: View {
    let product: Product
    let onSelect: (Product) -> Void

    var body: some View {
        Menu {
            ForEach(Product.allCases) { option in
                Button {
                    onSelect(option)
                } label: {
                    if option == product {
                        Label { Text(option.displayName) } icon: { Image(systemName: "checkmark") }
                    } else {
                        Text(option.displayName)
                    }
                }
            }
        } label: {
            Label { Text(product.displayName).lineLimit(1) } icon: { Image(systemName: "chevron.down") }
                .labelStyle(.trailingIcon)
        }
        .accentGlassMenu()
        .accessibilityLabel(Text("Combustible", bundle: .module))
        .accessibilityValue(Text(product.displayName))
    }
}

/// "Más barata | Más cerca".
struct SortPicker: View {
    @Binding var sort: StationSort

    var body: some View {
        Picker(selection: $sort) {
            Text("Más barata", bundle: .module).tag(StationSort.cheapest)
            Text("Más cerca", bundle: .module).tag(StationSort.nearest)
        } label: {
            Text("Ordenar", bundle: .module)
        }
        .pickerStyle(.segmented)
    }
}

/// "Todas · Baratas · Medias · Caras": black when selected, outlined otherwise.
struct LevelChips: View {
    @Binding var selection: LevelFilter

    var body: some View {
        HStack(spacing: 8) {
            ForEach(LevelFilter.allCases, id: \.self) { filter in
                let isSelected = selection == filter
                Button {
                    selection = filter
                } label: {
                    filter.title
                        .font(.footnote.weight(isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? ColorTokens.background : ColorTokens.textPrimary)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 32)
                        .background(isSelected ? ColorTokens.textPrimary : ColorTokens.surface, in: .capsule)
                        .overlay {
                            if !isSelected { Capsule().strokeBorder(ColorTokens.chipBorder, lineWidth: 1) }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Filtro de precio", bundle: .module))
    }
}

/// At accessibility text sizes the sort and the filter fold into one button (canvas: "Texto muy grande").
struct CompactFilters: View {
    @Bindable var viewModel: StationListViewModel

    var body: some View {
        Menu {
            Picker(selection: $viewModel.sort) {
                Text("Más barata", bundle: .module).tag(StationSort.cheapest)
                Text("Más cerca", bundle: .module).tag(StationSort.nearest)
            } label: {
                Text("Ordenar", bundle: .module)
            }
            Picker(selection: $viewModel.levelFilter) {
                ForEach(LevelFilter.allCases, id: \.self) { $0.title.tag($0) }
            } label: {
                Text("Filtro de precio", bundle: .module)
            }
        } label: {
            Label { Text("Filtros", bundle: .module) } icon: { Image(systemName: "line.3.horizontal.decrease") }
        }
        .accentGlassMenu()
    }
}

/// "Cerca de ti · 3 km · 23 estaciones" on the left, "Hace 12 min" on the right.
struct ListHeader: View {
    let viewModel: StationListViewModel

    @Environment(\.displayFormat) private var format
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(area)
            Spacer(minLength: 8)
            if let date = viewModel.pricesDate {
                // Re-evaluated every minute so "Hace 12 min" keeps up.
                TimelineView(.everyMinute) { context in
                    Text(format.relativeTime(date, now: context.date))
                }
            }
        }
        .font(.caption)
        .foregroundStyle(ColorTokens.textSecondary)
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    private var area: String {
        let count = viewModel.state.content?.rows.count
        if typeSize.isAccessibilitySize, let count {
            return String(localized: "\(count) cerca", bundle: .module, comment: "Header at very large text sizes")
        }
        var parts: [String] = []
        switch viewModel.scope {
        case .nearby(let radius):
            parts.append(String(localized: "Cerca de ti", bundle: .module))
            parts.append(format.distance(meters: radius))
        case .province(let name):
            parts.append(String(localized: "En \(name)", bundle: .module, comment: "Header without location: En Madrid"))
        case nil:
            break
        }
        if let count { parts.append(String(localized: "\(count) estaciones", bundle: .module)) }
        return parts.joined(separator: " · ")
    }
}

/// The white card of rows with separators inset past the brand badge.
struct StationCard: View {
    let rows: [StationListRow]
    let onSelect: (StationID) -> Void

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(rows) { row in
                Button {
                    onSelect(row.id)
                } label: {
                    StationRow(row.summary, hours: row.hours)
                        .padding(.horizontal, 14)
                }
                .buttonStyle(.plain)
                if row.id != rows.last?.id {
                    Rectangle()
                        .fill(ColorTokens.separator)
                        .frame(height: 1)
                        .padding(.leading, 66)
                }
            }
        }
        .background(ColorTokens.surface, in: .rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18).strokeBorder(ColorTokens.separator, lineWidth: 1)
        }
    }
}

struct EmptyListView: View {
    let reason: EmptyReason
    let showsMapAction: Bool
    let onShowMap: () -> Void
    let onShowAll: () -> Void

    @Environment(\.displayFormat) private var format

    var body: some View {
        switch reason {
        case .noStationsNearby(let product, let nearest):
            let name = String(localized: product.displayName)
            let tip = String(localized: "Mueve el mapa para ver otra zona o cambia de combustible.", bundle: .module)
            let message = nearest.map {
                String(localized: "La más cercana está a \(format.distance(meters: $0)).", bundle: .module) + " " + tip
            } ?? tip
            EmptyStateView(
                systemImage: "fuelpump.slash",
                title: String(localized: "No hay gasolineras con \(name) cerca", bundle: .module),
                message: message,
                actionTitle: showsMapAction ? String(localized: "Ver en el mapa", bundle: .module) : nil,
                action: showsMapAction ? onShowMap : nil
            )
        case .noStationsAtLevel(let level):
            EmptyStateView(
                systemImage: "line.3.horizontal.decrease.circle",
                title: level.emptyTitle,
                message: String(localized: "Prueba con «Todas» o con otro combustible.", bundle: .module),
                actionTitle: String(localized: "Ver todas", bundle: .module),
                action: onShowAll
            )
        case .noFavorites, .noSearchResults:
            EmptyView()
        }
    }
}

struct FailedListView: View {
    let error: DomainError
    let onRetry: () -> Void

    var body: some View {
        EmptyStateView(
            systemImage: error == .offline ? "wifi.slash" : "exclamationmark.icloud",
            title: error == .offline
                ? String(localized: "Sin conexión", bundle: .module)
                : String(localized: "No se pudieron cargar los precios", bundle: .module),
            message: error == .offline
                ? String(localized: "Conéctate a internet para ver los precios de hoy.", bundle: .module)
                : String(localized: "El servidor del ministerio no responde. Inténtalo de nuevo en unos minutos.", bundle: .module),
            actionTitle: String(localized: "Reintentar", bundle: .module),
            action: onRetry
        )
    }
}

extension LevelFilter {
    var title: Text {
        switch self {
        case .all: Text("Todas", bundle: .module)
        case .cheap: Text("Baratas", bundle: .module)
        case .average: Text("Medias", bundle: .module)
        case .expensive: Text("Caras", bundle: .module)
        }
    }
}

extension PriceLevel {
    var emptyTitle: String {
        switch self {
        case .cheap: String(localized: "No hay gasolineras baratas aquí", bundle: .module)
        case .average: String(localized: "No hay gasolineras de precio medio aquí", bundle: .module)
        case .expensive: String(localized: "No hay gasolineras caras aquí", bundle: .module)
        }
    }
}
