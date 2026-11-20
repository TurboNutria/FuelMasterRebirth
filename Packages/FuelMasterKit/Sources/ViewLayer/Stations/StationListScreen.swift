import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

/// Gasolineras (canvas: "Lista de gasolineras" and its states). Reads the view model and sends
/// intents back; the view model lives above the layouts, so nothing resets when they swap.
public struct StationListScreen: View {
    @Bindable var viewModel: StationListViewModel

    @Environment(AppRouter.self) private var router
    @Environment(\.dynamicTypeSize) private var typeSize

    public init(viewModel: StationListViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if router.layoutMode == .sideBySide {
                        // Side by side has no room for the title; the tab switcher names the screen.
                        HStack(spacing: 20) { fuelMenu; Spacer(minLength: 8); CompactFilters(viewModel: viewModel) }
                            .padding(.top, 4)
                    } else if typeSize.isAccessibilitySize {
                        // Canvas "Texto muy grande": title alone, then the fuel and one filters button.
                        title.padding(.top, 8)
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 20) { fuelMenu; CompactFilters(viewModel: viewModel) }
                            VStack(alignment: .leading, spacing: 12) { fuelMenu; CompactFilters(viewModel: viewModel) }
                        }
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 20) {
                            title.padding(.top, 8)
                            Spacer(minLength: 8)
                            fuelMenu
                            LevelMenu(selection: $viewModel.levelFilter)
                        }
                        SortPicker(sort: $viewModel.sort)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        ListHeader(viewModel: viewModel)
                        StationListContent(viewModel: viewModel)
                    }
                }
                .padding(.horizontal, Metrics.screenMargin)
                .padding(.bottom, 96)
            }
            .background(ColorTokens.background)
            .refreshable { await viewModel.refresh(force: true) }
            .overlay(alignment: .bottom) {
                StatusPillStack(isUpdating: isUpdating, showsOffline: viewModel.isOfflinePillVisible,
                                pricesDate: viewModel.pricesDate, onDismissOffline: viewModel.dismissOfflinePill)
                    .animation(.default, value: viewModel.isOfflinePillVisible)
            }
            #if os(iOS)
            .toolbarVisibility(.hidden, for: .navigationBar)
            #endif
            .navigationDestination(isPresented: router.detailPushBinding(on: .list)) {
                DetailPane(presentation: .push)
            }
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

    private var title: ScreenTitle {
        ScreenTitle(Text("Gasolineras", bundle: .module))
    }

    /// A property, as it's placed in three layouts above; the menu itself is `FuelMenu`.
    private var fuelMenu: FuelMenu {
        FuelMenu(product: viewModel.product, products: viewModel.offeredProducts, onSelect: selectFuel)
    }

    private var isUpdating: Bool {
        if case .updating = viewModel.state { return true }
        return false
    }

    private func selectFuel(_ product: Product) {
        Task { await viewModel.select(product) }
    }
}
