import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

/// Gasolineras below its header, for each screen state: the spinner, the rows, why it's empty,
/// or what failed.
struct StationListContent: View {
    let viewModel: StationListViewModel

    @Environment(AppRouter.self) private var router

    var body: some View {
        switch viewModel.state {
        case .firstLoad:
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .padding(.top, 120)
                .accessibilityLabel(Text("Cargando gasolineras", bundle: .module))
        case .content(let content), .updating(let content), .offline(let content, _):
            StationCard(rows: content.rows, onSelect: select, onToggleFavorite: toggleFavorite)
        case .empty(let reason):
            EmptyListView(reason: reason, showsMapAction: router.layoutMode.hasMapTab,
                          onShowMap: showMap, onShowAll: showAllLevels)
                .padding(.top, Metrics.emptyStateTop)
        case .failed(let error):
            FailedListView(error: error, onRetry: retry)
                .padding(.top, Metrics.emptyStateTop)
        }
    }

    private func select(_ station: StationID) {
        router.select(station)
    }

    private func toggleFavorite(_ summary: StationSummary) {
        Task { await viewModel.toggleFavorite(summary) }
    }

    private func showMap() {
        router.selectedTab = .map
    }

    private func showAllLevels() {
        viewModel.levelFilter = .all
    }

    private func retry() {
        Task { await viewModel.refresh(force: true) }
    }
}
