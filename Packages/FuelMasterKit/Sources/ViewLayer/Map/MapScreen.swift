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
    @State private var position: MapCameraPosition = .automatic
    @State private var width: Double = 390

    public init(viewModel: MapViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Map(position: $position) {
            UserAnnotation()
            ForEach(pins) { pin in
                Annotation("", coordinate: pin.coordinate.location, anchor: .bottom) {
                    Button {
                        tap(pin)
                    } label: {
                        MapPinView(pin: pin, isHighlighted: isHighlighted(pin))
                    }
                    .buttonStyle(.plain)
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls {}
        .onMapCameraChange(frequency: .onEnd) { context in
            viewModel.viewportChanged(MapViewport(context.region), width: width)
        }
        .onGeometryChange(for: Double.self) { $0.size.width } action: { width = $0 }
        .onChange(of: viewModel.cameraMove, initial: true) { _, move in
            guard let move else { return }
            withAnimation { position = .region(move.viewport.region) }
        }
        .overlay(alignment: .top) { topControls }
        .overlay(alignment: .bottom) { bottomStack }
        .task { await viewModel.start() }
    }

    private var pins: [StationPin] {
        if case .firstLoad = viewModel.state { return viewModel.placeholderPins }
        return viewModel.state.content?.pins ?? []
    }

    /// The selected station, or else the cheapest nearby (which is never grouped).
    private func isHighlighted(_ pin: StationPin) -> Bool {
        guard case .station(let summary) = pin else { return false }
        return summary.id == router.selectedStationID
            || (router.selectedStationID == nil && summary.id == viewModel.state.content?.cheapest?.summary.id)
    }

    private func tap(_ pin: StationPin) {
        switch pin {
        case .station(let summary): router.select(summary.id)
        case .cluster(_, _, let bounds): viewModel.zoom(into: bounds)
        case .placeholder: break
        }
    }

    // MARK: Overlays

    private var topControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                MapFuelMenu(product: viewModel.product) { product in
                    Task { await viewModel.select(product) }
                }
                MapLevelMenu(selection: $viewModel.levelFilter)
                Spacer()
                GlassIconButton(systemImage: "location.fill", label: Text("Centrar en mi ubicación", bundle: .module)) {
                    Task { await viewModel.centerOnUser() }
                }
            }
            statusPill
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    /// «Actualizado hace 12 min · media 1,924 €», «Cargando precios…» or the zoom hint.
    @ViewBuilder private var statusPill: some View {
        let text: String? = if viewModel.isZoomedOut {
            String(localized: "Acerca el mapa para ver los precios", bundle: .module)
        } else if case .firstLoad = viewModel.state {
            String(localized: "Cargando precios…", bundle: .module)
        } else if let content = viewModel.state.content, let date = content.pricesDate {
            [String(localized: "Actualizado \(format.relativeTimeInSentence(date, now: .now))", bundle: .module),
             content.average.map { String(localized: "media \(format.priceWithCurrency($0))", bundle: .module) }]
                .compactMap { $0 }.joined(separator: " · ")
        } else {
            nil
        }
        if let text {
            Text(text)
                .font(.caption)
                .foregroundStyle(ColorTokens.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
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
            if let cheapest = viewModel.state.content?.cheapest {
                CheapestCard(cheapest: cheapest) { router.select(cheapest.summary.id) }
                    .padding(.horizontal, 12)
            }
        }
        .padding(.bottom, 12)
    }
}

/// Fuel menu on the map: white glass with dark text, as on the canvas.
struct MapFuelMenu: View {
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
            HStack(spacing: 6) {
                Image(systemName: "fuelpump")
                Text(product.displayName).lineLimit(1)
                Image(systemName: "chevron.down").imageScale(.small)
            }
        }
        .mapControlMenu()
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
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease")
                selection.title.lineLimit(1)
            }
        }
        .mapControlMenu()
        .accessibilityLabel(Text("Filtro de precio", bundle: .module))
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

/// "La más barata cerca": name, hours and distance, the big price and its gap to the average,
/// with "Cómo llegar" and "Ver detalle".
struct CheapestCard: View {
    let cheapest: CheapestNearby
    let onDetail: () -> Void

    @Environment(\.displayFormat) private var format
    @Environment(\.accentColors) private var accent
    @Environment(\.priceScale) private var scale

    var body: some View {
        let summary = cheapest.summary
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("La más barata cerca", bundle: .module)
                    .font(.footnote.weight(.semibold))
                    .textCase(.uppercase)
                    .kerning(0.5)
                Spacer()
                Text(format.distance(meters: cheapest.radius))
                    .font(.footnote)
            }
            .foregroundStyle(ColorTokens.textSecondary)

            HStack(spacing: 12) {
                BrandBadge(summary.station.initials)
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.station.name)
                        .font(.headline)
                        .foregroundStyle(ColorTokens.textPrimary)
                    HStack(spacing: 0) {
                        HoursLabel(cheapest.hours).layoutPriority(2)
                        Group {
                            if let distance = summary.distance { Text(verbatim: " · \(format.distance(meters: distance))").layoutPriority(1) }
                            Text(verbatim: " · \(summary.station.address.street)")
                        }
                        .foregroundStyle(ColorTokens.textSecondary)
                    }
                    .font(.footnote)
                    .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: 0) {
                    Text(format.price(summary.price.amount))
                        .font(.system(.title, design: .rounded, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(priceColor)
                    if let gap = gapText {
                        Text(gap)
                            .font(.caption)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(spokenText)

            HStack(spacing: 8) {
                Button {
                    openDirections()
                } label: {
                    Text("Cómo llegar", bundle: .module)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(accent.onFill)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(accent.fill)
                .controlSize(.large)

                Button(action: onDetail) {
                    Text("Ver detalle", bundle: .module)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(accent.tint)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
            }
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
    }

    /// Cheap prices in their scale colour; average and expensive ones stay dark so they read on glass.
    private var priceColor: Color {
        cheapest.summary.level == .cheap
            ? PriceLevelColors.colors(for: .cheap, scale: scale).background
            : ColorTokens.textPrimary
    }

    private var gapText: String? {
        guard let gap = cheapest.belowAverage else { return nil }
        let amount = format.priceWithCurrency(abs(gap))
        if gap > 0 { return String(localized: "\(amount) bajo la media", bundle: .module) }
        if gap < 0 { return String(localized: "\(amount) sobre la media", bundle: .module) }
        return String(localized: "En la media", bundle: .module)
    }

    /// «La más barata cerca: Ballenoil, 1,859 euros, 0,065 euros bajo la media.»
    private var spokenText: String {
        let price = format.priceWithCurrency(cheapest.summary.price.amount)
        let parts = [cheapest.summary.station.name, price, gapText].compactMap { $0 }.joined(separator: ", ")
        return String(localized: "La más barata cerca: \(parts)", bundle: .module)
    }

    private func openDirections() {
        let coordinate = cheapest.summary.station.coordinate
        let item = MKMapItem(location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude), address: nil)
        item.name = cheapest.summary.station.name
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
