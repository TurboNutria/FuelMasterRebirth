import DomainLayer
import SwiftUI

/// TEMPORARY: a developer screen that proves the data stack works end to end (location or default
/// province → ministry → SwiftData cache → nearby stations). Replaced by RootView in the UI step.
struct DataCheckView: View {
    let dependencies: AppDependencies

    @State private var lines: [String] = ["Cargando…"]
    @State private var stations: [StationSummary] = []

    var body: some View {
        NavigationStack {
            List {
                Section("Estado") {
                    ForEach(lines, id: \.self) { Text($0).font(.footnote.monospaced()) }
                }
                Section("Diésel más barato · 3 km de Sol") {
                    ForEach(stations.prefix(10)) { summary in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(summary.station.name).font(.headline)
                                Text(summary.station.address.street).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(summary.price.amount, format: .number.precision(.fractionLength(3)))
                                .font(.system(.body, design: .rounded).bold())
                        }
                    }
                }
            }
            .navigationTitle("FuelMaster · datos")
            .task { await load() }
            .refreshable { await load(force: true) }
        }
    }

    private func load(force: Bool = false) async {
        let sol = Coordinate(latitude: 40.4169, longitude: -3.7035)
        let provinces = await dependencies.resolveProvinces(around: sol)
        lines = ["Provincias: \(provinces.map(\.rawValue).joined(separator: ", "))"]

        let start = Date()
        let outcome = await dependencies.refreshPrices(provinces, force: force)
        lines.append("Actualizadas: \(outcome.updated.map(\.rawValue)) · omitidas: \(outcome.skipped.map(\.rawValue))")
        if !outcome.failed.isEmpty { lines.append("Errores: \(outcome.failed)") }
        lines.append(String(format: "Tiempo: %.1f s", Date().timeIntervalSince(start)))

        let request = NearbyRequest(provinces: provinces, area: .radius(center: sol, meters: 3000),
                                    product: .diesel, origin: sol)
        if let result = try? await dependencies.observeNearbyStations.load(request) {
            stations = result.stations
            if let summary = result.summary {
                lines.append("Media: \(summary.average.formatted(.number.precision(.fractionLength(3)))) € · \(summary.stationCount) estaciones")
            }
        }
    }
}
