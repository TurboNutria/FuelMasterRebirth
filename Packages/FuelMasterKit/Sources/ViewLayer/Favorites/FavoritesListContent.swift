import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

/// Favoritos' rows for each screen state, inside its list: the spinner, the empty state, the
/// stations (swipe to remove, drag to reorder in Editar) with the iCloud note, or the failure.
struct FavoritesListContent: View {
    let viewModel: FavoritesViewModel

    @Environment(AppRouter.self) private var router

    var body: some View {
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
                    FavoriteRowView(row: row, product: viewModel.product) { open(row.id) }
                        .modifier(FavoriteRowActions(station: row.item.station) { remove(row.id) })
                        .modifier(FavoriteContextMenu(row: row, onRemove: { remove(row.id) }, onOpen: { open(row.id) }))
                        // Hairlines end where the chips end, as in Gasolineras.
                        .alignmentGuide(.listRowSeparatorTrailing) { $0[.trailing] }
                        .listRowInsets(EdgeInsets(top: 0, leading: Metrics.screenMargin,
                                                  bottom: 0, trailing: Metrics.screenMargin))
                        .listRowBackground(Color.clear)
                        .listRowSeparatorTint(ColorTokens.separator)
                        .listRowSeparator(row.id == content.rows.first?.id ? .hidden : .visible, edges: .top)
                        .listRowSeparator(row.id == content.rows.last?.id ? .hidden : .visible, edges: .bottom)
                        .swipeActions {
                            Button(role: .destructive) { remove(row.id) } label: {
                                Label { Text("Quitar", bundle: .module) } icon: { Image(systemName: "star.slash") }
                            }
                        }
                }
                .onMove(perform: move)
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
            FailedListView(error: error, onRetry: retry)
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

    private func open(_ station: StationID) {
        router.select(station)
    }

    private func remove(_ station: StationID) {
        Task { await viewModel.remove(station) }
    }

    private func move(_ source: IndexSet, _ destination: Int) {
        guard let from = source.first else { return }
        // List gives the destination before removal; the repository wants it after.
        let to = destination > from ? destination - 1 : destination
        Task { await viewModel.move(from: from, to: to) }
    }

    private func retry() {
        Task { await viewModel.refresh(force: true) }
    }
}
