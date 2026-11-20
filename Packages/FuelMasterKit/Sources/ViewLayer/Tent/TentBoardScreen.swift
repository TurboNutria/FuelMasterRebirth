import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

/// The closed iPhone Duo in landscape ("tent"): too small for list and map side by side, so the
/// screen becomes a forecourt price sign (canvas: Tent Price Board). It shows the selected station,
/// or else the cheapest open one nearby (`TentBoardChoice`). Laid out on the design's 880 × 440
/// grid and scaled to fit.
struct TentBoardScreen: View {
    @Environment(AppRouter.self) private var router
    @Environment(StationListViewModel.self) private var stationList
    @Environment(TentBoardViewModel.self) private var board
    @Environment(SettingsViewModel.self) private var settings

    var body: some View {
        let choice = TentBoardChoice(selected: router.selectedStationID,
                                     nearby: stationList.state.content?.rows.map(\.summary) ?? [])
        GeometryReader { proxy in
            let scale = min(proxy.size.width / TentBoard.designSize.width, proxy.size.height / TentBoard.designSize.height)
            Group {
                if let content = board.content, content.station.id == choice.stationID {
                    TentBoard(content: content, caption: caption(choice.caption(isFavorite: content.detail.isFavorite)),
                              distance: choice.distance(for: content), nearestOpen: choice.nearestOpen, scale: scale)
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
        .task(id: TaskKey(station: choice.stationID, product: settings.settings.product)) {
            guard let stationID = choice.stationID else { return }
            await board.show(stationID, product: settings.settings.product, tankSize: settings.settings.tankSize)
        }
    }

    private struct TaskKey: Equatable {
        let station: StationID?
        let product: Product
    }

    private func caption(_ caption: TentBoardChoice.Caption?) -> Text? {
        switch caption {
        case .cheapestNearby: Text("Más barata cerca", bundle: .module)
        case .favorite: Text("Favorita", bundle: .module)
        case nil: nil
        }
    }
}
