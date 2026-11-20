#if os(watchOS)
import DesignTokens
import DomainLayer
import MapKit
import SwiftUI
import ViewModelLayer

/// One station (canvas: Watch · Detalle): price, gap to the average, hours, distance, street,
/// then directions and the favourite toggle. Each pushed detail has its own view model, since
/// both pages can hold one at the same time.
struct WatchDetailScreen: View {
    let id: StationID
    @State private var viewModel: WatchStationDetailViewModel

    init(id: StationID, viewModel: WatchStationDetailViewModel) {
        self.id = id
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            switch viewModel.state {
            case .firstLoad:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
            case .content(let content), .updating(let content), .offline(let content, _):
                WatchDetailContent(content: content) {
                    Task { await viewModel.toggleFavorite() }
                }
            case .failed, .empty:
                WatchMessage(systemImage: "fuelpump.slash",
                             text: String(localized: "No se pudieron cargar los precios", bundle: .module))
            }
        }
        .task(id: id) { await viewModel.show(id) }
    }
}

private struct WatchDetailContent: View {
    let content: WatchStationDetailContent
    let onToggleFavorite: () -> Void

    @Environment(\.displayFormat) private var format
    @Environment(\.priceScale) private var scale
    @Environment(\.accentColors) private var accent

    var body: some View {
        let detail = content.detail
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                StationLogo(brand: detail.station.brand, size: 26)
                Text(detail.station.name)
                    .font(.title3.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            Text(content.product.watchName)
                .font(.footnote)
                .foregroundStyle(ColorTokens.textSecondary)
            price(detail)
            GapLine(belowAverage: detail.belowAverage, spacing: 3)
                .font(.footnote.weight(.semibold))

            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: hoursAndDistance(detail))
                    .monospacedDigit()
                    .accessibilityLabel(Text(verbatim: spokenHoursAndDistance(detail)))
                Text(detail.station.address.street)
            }
            .font(.footnote)
            .foregroundStyle(ColorTokens.textSecondary)
            .padding(.top, 8)
            .padding(.bottom, 10)

            Button {
                detail.station.openDirections()
            } label: {
                Label { Text("Cómo llegar", bundle: .module) } icon: { Image(systemName: "location.north.fill") }
                    .foregroundStyle(accent.onFill)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(accent.fill)

            Button(action: onToggleFavorite) {
                Label {
                    Text("Favorita", bundle: .module)
                } icon: {
                    Image(systemName: content.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(accent.tint)
                }
                .foregroundStyle(ColorTokens.textPrimary)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            // A plain platter: only the star carries the accent (canvas: Watch · Detalle).
            .tint(.white)
            .accessibilityAddTraits(content.isFavorite ? .isSelected : [])
        }
    }

    @ViewBuilder private func price(_ detail: StationDetail) -> some View {
        if let price = detail.price {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(format.price(price.amount))
                    .font(.watchHeroPrice)
                    .monospacedDigit()
                    .foregroundStyle(detail.level == .cheap
                                     ? PriceLevelColors.colors(for: .cheap, scale: scale).background
                                     : ColorTokens.textPrimary)
                Text(verbatim: price.unit == .kilogram ? "€/kg" : "€/l")
                    .font(.footnote)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: [format.priceWithCurrency(price.amount), detail.level?.spokenName]
                .compactMap { $0 }.joined(separator: ", ")))
        } else {
            Text("Esta gasolinera no vende \(content.product.watchName)", bundle: .module)
                .font(.headline)
                .padding(.vertical, 4)
        }
    }

    private func hoursAndDistance(_ detail: StationDetail) -> String {
        let hours = content.hours.isClosed ? String(localized: "Cerrada", bundle: .module) : content.hours.visibleText
        guard let distance = detail.distance else { return hours }
        return "\(hours) · \(format.distance(meters: distance))"
    }

    private func spokenHoursAndDistance(_ detail: StationDetail) -> String {
        guard let distance = detail.distance else { return content.hours.spokenText }
        return "\(content.hours.spokenText). " + String(localized: "A \(format.distance(meters: distance))",
                                                         bundle: .module, comment: "Distance from you")
    }
}

extension Station {
    /// Driving directions in Maps on the watch.
    func openDirections() {
        let item = MKMapItem(location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
                             address: nil)
        item.name = name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}
#endif
