import DomainLayer
import MapKit
import SwiftUI
import ViewModelLayer

/// Mapa (canvas: "Mapa de gasolineras", "Primera carga, mapa"). Full-bleed map; its controls
/// respect the safe area. The view model keeps the viewport, so a layout change reopens the map
/// where it was.
public struct MapScreen: View {
    @Bindable var viewModel: MapViewModel

    @Environment(AppRouter.self) private var router
    @Environment(\.displayFormat) private var format
    @Environment(\.freeTopInset) private var freeTopInset
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public init(viewModel: MapViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        // The controls stay inside the safe area; only the map runs under it.
        Color.clear
            .background {
                PinMap(pins: pins, highlightedID: router.highlightedStationID, cameraMove: viewModel.cameraMove,
                       showsUserLocation: viewModel.showsUserLocation,
                       onViewportChange: { viewport, width, distance in
                           viewModel.viewportChanged(viewport, width: width, distance: distance)
                       },
                       onTap: tap)
                    .ignoresSafeArea()
            }
            // The controls over the map stop growing at the largest standard size, as in Maps, so
            // the row fits; holding one shows it in the large content viewer.
            .overlay(alignment: .top) { topControls.dynamicTypeSize(...DynamicTypeSize.xxxLarge) }
            .overlay(alignment: .bottom) { bottomStack.dynamicTypeSize(...DynamicTypeSize.xxxLarge) }
            .task { await viewModel.start() }
    }

    private var pins: [StationPin] {
        if case .firstLoad = viewModel.state { return viewModel.placeholderPins }
        return viewModel.state.content?.pins ?? []
    }

    private func tap(_ pin: StationPin) {
        switch pin {
        case .station(let summary): router.select(summary.id, from: .map)
        case .cluster(_, _, let bounds): viewModel.zoom(into: bounds)
        case .placeholder: break
        }
    }

    // MARK: Overlays

    private var topControls: some View {
        // One container for the controls over the map, so their glass samples the map together.
        // Spacing 0: they stay separate shapes rather than melting into each other.
        GlassEffectContainer(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    Group {
                        if !router.layoutMode.hasMapTab { panelButton }
                        if router.showsMapMenus {
                            MapFuelMenu(product: viewModel.product, products: viewModel.offeredProducts) { product in
                                Task { await viewModel.select(product) }
                            }
                            MapLevelMenu(selection: $viewModel.levelFilter)
                        } else {
                            // A filter set before the list came back still applies, so it stays visible.
                            if viewModel.levelFilter != .all { MapLevelMenu(selection: $viewModel.levelFilter) }
                            // With the list beside the map its fuel and filters are already on screen,
                            // so the pill takes their place instead of floating below.
                            statusPill
                        }
                    }
                    .offset(y: -leftControlsLift)
                    Spacer(minLength: 8)
                    GlassIconButton(systemImage: "location.fill", label: Text("Centrar en mi ubicación", bundle: .module)) {
                        Task { await viewModel.centerOnUser() }
                    }
                }
                if router.showsMapMenus { statusPill.offset(y: -leftControlsLift) }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    /// How far the left-hand controls rise into free space, ending 16 pt from the top like the
    /// panel's tab switcher. The location button stays below the status corner.
    private var leftControlsLift: CGFloat {
        freeTopInset > 0 ? max(0, freeTopInset - 8) : 0
    }

    /// Hides or brings back the list panel.
    private var panelButton: some View {
        GlassIconButton(systemImage: "sidebar.left",
                        label: router.isPanelCollapsed ? Text("Mostrar lista", bundle: .module) : Text("Ocultar lista", bundle: .module)) {
            // Reduce Motion: the panel appears and goes without sliding.
            withAnimation(reduceMotion ? nil : .default) { router.isPanelCollapsed.toggle() }
        }
    }

    /// «Cargando precios…» or the zoom hint. Nothing once prices are on the map.
    @ViewBuilder private var statusPill: some View {
        let text: String? = if viewModel.isZoomedOut {
            String(localized: "Acerca el mapa para ver los precios", bundle: .module)
        } else if case .firstLoad = viewModel.state {
            String(localized: "Cargando precios…", bundle: .module)
        } else {
            nil
        }
        if let text {
            Text(text)
                .font(.caption)
                // Wraps at large text sizes rather than cutting the message.
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(ColorTokens.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .glassEffect(.regular, in: .capsule)
        }
    }

    private var bottomStack: some View {
        VStack(spacing: 10) {
            if case .updating = viewModel.state { UpdatingPill() }
            if viewModel.isOfflinePillVisible {
                OfflinePill(age: viewModel.state.content?.pricesDate.map { format.relativeTimeInSentence($0, now: .now) }) {
                    viewModel.dismissOfflinePill()
                }
            }
        }
        .padding(.bottom, 12)
    }
}

/// Fuel menu on the map: white glass with dark text, as on the canvas.
struct MapFuelMenu: View {
    let product: Product
    let products: [Product]
    let onSelect: (Product) -> Void

    var body: some View {
        Menu {
            // A picker, so the system draws the tick in its own column and the names stay aligned.
            Picker(selection: Binding(get: { product }, set: onSelect)) {
                ForEach(products) { Text($0.displayName).tag($0) }
            } label: {
                Text("Combustible", bundle: .module)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "fuelpump")
                // Grows with the text rather than truncating "Diésel Premium" (accessibility audit).
                Text(product.displayName).fixedSize()
                Image(systemName: "chevron.down").imageScale(.small)
            }
        }
        .mapControlMenu()
        .accessibilityShowsLargeContentViewer()
        .accessibilityLabel(Text("Combustible", bundle: .module))
        .accessibilityValue(Text(product.displayName))
    }
}

struct MapLevelMenu: View {
    @Binding var selection: LevelFilter

    var body: some View {
        Menu {
            Picker(selection: $selection) {
                ForEach(LevelFilter.allCases, id: \.self) { $0.title.tag($0) }
            } label: {
                Text("Filtro de precio", bundle: .module)
            }
        } label: {
            FilterIcon(isActive: selection != .all)
        }
        .mapControlMenu()
        .accessibilityLabel(Text("Filtro de precio", bundle: .module))
        .accessibilityValue(selection.title)
    }
}

extension View {
    /// Glass capsule with dark text for controls floating over the map.
    func mapControlMenu() -> some View {
        self
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(ColorTokens.textPrimary)
            .menuStyle(.button)
            .buttonStyle(.glass)
            .controlSize(.large)
    }
}

extension Station {
    /// "Cómo llegar": Apple Maps with driving directions to the station.
    func openDirections() {
        let item = MKMapItem(location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude), address: nil)
        item.name = name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}

extension Coordinate {
    var location: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}

extension MapViewport {
    init(_ region: MKCoordinateRegion) {
        self.init(center: Coordinate(latitude: region.center.latitude, longitude: region.center.longitude),
                  latitudeDelta: region.span.latitudeDelta, longitudeDelta: region.span.longitudeDelta)
    }

    var region: MKCoordinateRegion {
        MKCoordinateRegion(center: center.location,
                           span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta))
    }
}
