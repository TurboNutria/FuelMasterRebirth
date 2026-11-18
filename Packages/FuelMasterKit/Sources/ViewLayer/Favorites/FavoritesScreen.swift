import DomainLayer
import SwiftUI
import ViewModelLayer

/// Favoritos (canvas: "Favoritos", "Favoritos vacío", iPad "Favoritos"): the cheapest favourite,
/// then the user's stations in their order with the change since yesterday. Swipe to remove;
/// Editar to reorder. Kept short on purpose: no explanatory text.
public struct FavoritesScreen: View {
    let viewModel: FavoritesViewModel

    @Environment(AppRouter.self) private var router
    @State private var isEditing = false
    @Environment(\.dynamicTypeSize) private var typeSize

    public init(viewModel: FavoritesViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    header
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                .listRowSeparator(.hidden)
                content
            }
            // Rows straight on the background with hairlines, like Gasolineras.
            .listStyle(.plain)
            #if os(iOS)
            .environment(\.editMode, .constant(isEditing ? .active : .inactive))
            #endif
            .scrollContentBackground(.hidden)
            .background(ColorTokens.background)
            .refreshable { await viewModel.refresh(force: true) }
            .overlay(alignment: .bottom) {
                if case .updating = viewModel.state { UpdatingPill().padding(.bottom, 12) }
            }
            #if os(iOS)
            .toolbarVisibility(.hidden, for: .navigationBar)
            #endif
            .navigationDestination(isPresented: router.detailPushBinding(on: .favorites)) {
                DetailPane(presentation: .push)
            }
        }
        .task { await viewModel.start() }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            if typeSize.isAccessibilitySize {
                // Title alone, as in Gasolineras, so it doesn't run into Editar.
                VStack(alignment: .leading, spacing: 8) { title; editButton }
                    .padding(.top, 8)
            } else {
                HStack(alignment: .lastTextBaseline) {
                    title
                    Spacer(minLength: 8)
                    editButton
                }
                .padding(.top, 8)
            }
            if let best = viewModel.state.content?.best { BestFavoriteCard(best: best) }
        }
        .padding(.bottom, 24)
    }

    private var title: some View {
        Text("Favoritos", bundle: .module)
            .font(.screenTitle)
            .foregroundStyle(ColorTokens.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .accessibilityAddTraits(.isHeader)
    }

    private var editButton: some View {
        Button {
            withAnimation { isEditing.toggle() }
        } label: {
            isEditing ? Text("Hecho", bundle: .module) : Text("Editar", bundle: .module)
        }
        .font(.body.weight(.semibold))
        // Borderless keeps the accent tint inside a plain list row and limits the tap to the text.
        .buttonStyle(.borderless)
        .disabled(viewModel.state.content == nil)
    }

    // MARK: Rows

    @ViewBuilder private var content: some View {
        switch viewModel.state {
        case .firstLoad:
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
                .listRowBackground(Color.clear)
        case .empty:
            EmptyStateView(systemImage: "star",
                           title: String(localized: "Aún no tienes favoritas", bundle: .module),
                           message: String(localized: "Toca la estrella en una gasolinera para añadirla.", bundle: .module))
                .padding(.top, 40)
                .listRowBackground(Color.clear)
        case .content(let content), .updating(let content), .offline(let content, _):
            Section {
                ForEach(content.rows) { row in
                    FavoriteRowView(row: row, product: viewModel.product) { router.select(row.id) }
                        // Hairlines end where the chips end, as in Gasolineras.
                        .alignmentGuide(.listRowSeparatorTrailing) { $0[.trailing] }
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparatorTint(ColorTokens.separator)
                        .listRowSeparator(row.id == content.rows.first?.id ? .hidden : .visible, edges: .top)
                        .listRowSeparator(row.id == content.rows.last?.id ? .hidden : .visible, edges: .bottom)
                        .swipeActions {
                            Button(role: .destructive) {
                                Task { await viewModel.remove(row.id) }
                            } label: {
                                Label { Text("Quitar", bundle: .module) } icon: { Image(systemName: "star.slash") }
                            }
                        }
                        .modifier(FavoriteRowActions(station: row.item.station) {
                            Task { await viewModel.remove(row.id) }
                        })
                }
                .onMove { source, destination in
                    guard let from = source.first else { return }
                    // List gives the destination before removal; the repository wants it after.
                    let to = destination > from ? destination - 1 : destination
                    Task { await viewModel.move(from: from, to: to) }
                }
            } footer: {
                if let iCloudProblem {
                    Text(iCloudProblem)
                        .font(.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 6)
                }
            }
        case .failed(let error):
            FailedListView(error: error) { Task { await viewModel.refresh(force: true) } }
                .listRowBackground(Color.clear)
        }
    }

    /// Only said when sync can't work; nothing when it's fine (or off in this build).
    private var iCloudProblem: String? {
        switch viewModel.iCloudStatus {
        case .noAccount: String(localized: "Inicia sesión en iCloud para sincronizarlas.", bundle: .module)
        case .restricted, .temporarilyUnavailable: String(localized: "iCloud no está disponible.", bundle: .module)
        case .available, .syncDisabled: nil
        }
    }
}

/// "La más barata": the cheapest favourite and its full tank, set straight on the page with the
/// price as the screen's one large figure. At accessibility sizes the price moves under the name.
struct BestFavoriteCard: View {
    let best: BestFavorite

    @Environment(\.displayFormat) private var format
    @Environment(\.priceScale) private var scale
    @Environment(\.dynamicTypeSize) private var typeSize
    /// 44 pt at the default size, growing with Dynamic Type.
    @ScaledMetric(relativeTo: .largeTitle) private var priceSize: CGFloat = 44

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    label
                    name
                    price
                    cost
                }
            } else {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        label
                        name
                        cost
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    price
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var label: some View {
        Text("La más barata", bundle: .module)
            .font(.footnote)
            .foregroundStyle(ColorTokens.textSecondary)
    }

    private var name: some View {
        Text(best.summary.station.name)
            .font(.title3.weight(.semibold))
            .foregroundStyle(ColorTokens.textPrimary)
    }

    @ViewBuilder private var cost: some View {
        if let cost = best.fuelCost {
            Text("Depósito lleno (\(format.quantity(cost.quantity, unit: cost.unit))): \(format.money(cost.amount))",
                 bundle: .module)
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(ColorTokens.textSecondary)
        }
    }

    private var price: some View {
        Text(format.price(best.summary.price.amount))
            .font(.system(size: priceSize, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(priceColor)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    /// The cheap colour when it's cheap for the area; plain ink otherwise. Monochrome's cheap fill
    /// is ink anyway.
    private var priceColor: Color {
        best.summary.level == .cheap ? PriceLevelColors.colors(for: .cheap, scale: scale).background : ColorTokens.textPrimary
    }
}

/// A favourite: the usual station row with the change since yesterday, or a placeholder while its
/// province loads or when it doesn't sell the chosen fuel.
struct FavoriteRowView: View {
    let row: FavoriteRow
    let product: Product
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            if let summary = row.summary, let hours = row.hours {
                StationRow(summary, hours: hours, change: row.change, showsFavoriteStar: false)
            } else {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.item.station?.name ?? String(localized: "Gasolinera", bundle: .module))
                            .font(.rowTitle)
                            .foregroundStyle(ColorTokens.textPrimary)
                        Group {
                            if row.isNotSold {
                                Text("No vende \(String(localized: product.displayName))", bundle: .module)
                            } else {
                                Text("Cargando precios…", bundle: .module)
                            }
                        }
                        .font(.rowDetail)
                        .foregroundStyle(ColorTokens.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    PriceChip(amount: nil, level: nil)
                }
                .padding(.vertical, 12)
                .frame(minHeight: 60)
                .contentShape(.rect)
            }
        }
        .buttonStyle(.plain)
        .disabled(row.item.station == nil)
    }
}

/// "Quitar de favoritos" and, once the station is loaded, "Cómo llegar".
private struct FavoriteRowActions: ViewModifier {
    let station: Station?
    let onRemove: () -> Void

    func body(content: Content) -> some View {
        if let station {
            content.stationRowActions(station, isFavorite: true, onToggleFavorite: onRemove)
        } else {
            content.accessibilityAction(named: Text("Quitar de favoritos", bundle: .module), onRemove)
        }
    }
}
