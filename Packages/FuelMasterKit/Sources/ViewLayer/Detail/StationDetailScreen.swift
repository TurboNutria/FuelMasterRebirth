import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

/// Detalle de estación (canvas: "Detalle de estación" and the iPad inspector): name and hours,
/// the price against the area with the full-tank cost, the 7-day chart, other fuels, and
/// "Cómo llegar". Compartir and the favourite star sit in the toolbar.
struct StationDetailScreen: View {
    let viewModel: StationDetailViewModel
    let stationID: StationID
    let presentation: DetailPresentation

    @Environment(AppRouter.self) private var router
    @Environment(\.displayFormat) private var format

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
                DetailBody(content: content, compact: presentation == .inspector, onRetryHistory: retryHistory)
                .frame(maxWidth: 672)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Metrics.screenMargin)
                .padding(.bottom, 16)
            }
            #if os(iOS)
            // A compact button in the bottom bar rather than a full-width one over the content
            // (QA on the Duo, 2026-10-29). The inspector has no bar of its own: its item landed
            // on the window's, half over the map.
            .toolbar {
                if presentation != .inspector {
                    if showsMapButton {
                        ToolbarItem(placement: .bottomBar) { ShowOnMapButton(station: content.station, keepsDetail: false) }
                        ToolbarSpacer(.fixed, placement: .bottomBar)
                    }
                    ToolbarItem(placement: .bottomBar) { DirectionsButton(station: content.station) }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if presentation == .inspector {
                    GlassEffectContainer(spacing: 0) {
                        HStack(spacing: 12) {
                            if showsMapButton {
                                ShowOnMapButton(station: content.station, keepsDetail: true)
                                    .buttonStyle(.glass)
                                    .buttonBorderShape(.circle)
                            }
                            DirectionsButton(station: content.station)
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

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        // A leading item in the inspector would land on the map's toolbar, so it closes from the
        // trailing group there; the sheet keeps the usual leading close button.
        if presentation == .sheet || presentation == .pane {
            ToolbarItem(placement: .cancellationAction) { CloseDetailButton() }
        }
        if presentation == .inspector, viewModel.state.content == nil {
            ToolbarItem(placement: .primaryAction) { CloseDetailButton() }
        }
        if let content = viewModel.state.content {
            ToolbarItemGroup(placement: .primaryAction) {
                if let url = viewModel.shareURL {
                    ShareLink(item: url, subject: Text(content.station.name), message: Text(shareMessage(content))) {
                        Label { Text("Compartir", bundle: .module) } icon: { Image(systemName: "square.and.arrow.up") }
                    }
                }
                FavoriteToggleButton(isFavorite: content.isFavorite, action: toggleFavorite)
                if presentation == .inspector { CloseDetailButton() }
            }
        }
    }

    private func toggleFavorite() {
        Task { await viewModel.toggleFavorite() }
    }

    private func retryHistory() {
        Task { await viewModel.retryHistory() }
    }

    private func shareMessage(_ content: StationDetailContent) -> String {
        StationShare.message(content.station, price: content.detail.price, format: format)
    }
}
