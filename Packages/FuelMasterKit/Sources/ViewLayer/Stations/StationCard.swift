import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

/// The rows, straight on the background with hairlines between them.
struct StationCard: View {
    let rows: [StationListRow]
    let onSelect: (StationID) -> Void
    let onToggleFavorite: (StationSummary) -> Void

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(rows) { row in
                Button {
                    onSelect(row.id)
                } label: {
                    StationRow(row.summary, hours: row.hours)
                }
                .buttonStyle(.plain)
                .stationRowActions(row.summary.station, isFavorite: row.summary.isFavorite) {
                    onToggleFavorite(row.summary)
                }
                .stationContextMenu(row.summary, hours: row.hours, isFavorite: row.summary.isFavorite,
                                    onToggleFavorite: { onToggleFavorite(row.summary) },
                                    onOpen: { onSelect(row.id) })
                if row.id != rows.last?.id {
                    RowSeparator()
                }
            }
        }
    }
}
