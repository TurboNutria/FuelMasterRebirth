import DomainLayer
import SwiftUI
import ViewModelLayer

/// Buscar (canvas: "Buscar", "Sin resultados"): the search field at the top, scopes
/// Todo / Marca / Localidad / C. P., and results with the match highlighted.
public struct SearchScreen: View {
    @Bindable var viewModel: SearchViewModel

    @Environment(AppRouter.self) private var router

    public init(viewModel: SearchViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Group {
            if usesSystemField {
                // The search tab's own field, which the tab bar turns into.
                stack.searchable(text: $viewModel.text, prompt: prompt)
            } else {
                stack
            }
        }
        .task { await viewModel.start() }
    }

    /// Only the tab bar has a place for the system field. In a panel it left an empty navigation
    /// bar above the title and, on iPhone, a field cut off at the bottom (QA on the Duo, 2026-11-11).
    private var usesSystemField: Bool { router.layoutMode == .tabs }

    private var prompt: Text { Text("Marca, localidad o C. P.", bundle: .module) }

    private var stack: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Buscar", bundle: .module)
                        .font(.screenTitle)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, 8)
                    if !usesSystemField { SearchField(text: $viewModel.text, prompt: prompt) }
                    Picker(selection: $viewModel.scope) {
                        ForEach(SearchScope.allCases, id: \.self) { $0.title.tag($0) }
                    } label: {
                        Text("Buscar en", bundle: .module)
                    }
                    .pickerStyle(.segmented)
                    if let summary { Text(summary).font(.footnote).foregroundStyle(ColorTokens.textSecondary) }
                    results
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.immediately)
            .background(ColorTokens.background)
            #if os(iOS)
            // Hidden like the other tabs, so the title sits at the same height. The search tab's
            // field lives in the tab bar and doesn't need it.
            .toolbarVisibility(.hidden, for: .navigationBar)
            #endif
            .navigationDestination(isPresented: router.detailPushBinding(on: .search)) {
                DetailPane(presentation: .push)
            }
        }
    }

    @ViewBuilder private var results: some View {
        if viewModel.isIdle {
            EmptyStateView(systemImage: "magnifyingglass",
                           title: String(localized: "Busca una gasolinera", bundle: .module),
                           message: String(localized: "Por marca, localidad o código postal.", bundle: .module))
                .padding(.top, 60)
        } else {
            switch viewModel.state {
            case .firstLoad:
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
            case .content(let content), .updating(let content), .offline(let content, _):
                SearchResultsCard(content: content, onSelect: { router.select($0) },
                                  onToggleFavorite: { summary in Task { await viewModel.toggleFavorite(summary) } })
            case .empty(.noSearchResults(let text)):
                EmptyStateView(systemImage: "magnifyingglass",
                               title: String(localized: "Sin resultados para «\(text)»", bundle: .module),
                               message: String(localized: "Prueba con una marca, una localidad o un código postal distinto.", bundle: .module))
                    .padding(.top, 60)
            case .empty:
                EmptyView()
            case .failed(let error):
                FailedListView(error: error) { viewModel.retry() }
                    .padding(.top, 60)
            }
        }
    }

    /// «Marca «Repsol» cerca de ti · más cercanas primero»
    private var summary: String? {
        guard !viewModel.isIdle, let content = viewModel.state.content else { return nil }
        let quoted = "«\(content.text)»"
        let what: String = switch content.scope {
        case .brand:
            if let area = content.areaName {
                String(localized: "Marca \(quoted) en \(area)", bundle: .module)
            } else {
                String(localized: "Marca \(quoted) cerca de ti", bundle: .module)
            }
        case .locality: String(localized: "Localidad \(quoted)", bundle: .module)
        case .postcode: String(localized: "C. P. \(quoted)", bundle: .module)
        case .all: quoted
        }
        let order = content.sortedByDistance
            ? String(localized: "más cercanas primero", bundle: .module)
            : String(localized: "más baratas primero", bundle: .module)
        return "\(what) · \(order)"
    }
}

extension SearchScope {
    var title: Text {
        switch self {
        case .all: Text("Todo", bundle: .module)
        case .brand: Text("Marca", bundle: .module)
        case .locality: Text("Localidad", bundle: .module)
        case .postcode: Text("C. P.", bundle: .module, comment: "Postcode, short")
        }
    }
}

/// The panel's own search field, under the title.
struct SearchField: View {
    @Binding var text: String
    let prompt: Text

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(ColorTokens.textSecondary)
                .accessibilityHidden(true)
            TextField(text: $text, prompt: prompt) { Text("Buscar", bundle: .module) }
                .autocorrectionDisabled()
                .submitLabel(.search)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Borrar", bundle: .module))
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background(ColorTokens.cell, in: .capsule)
    }
}

struct SearchResultsCard: View {
    let content: SearchContent
    let onSelect: (StationID) -> Void
    let onToggleFavorite: (StationSummary) -> Void

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(content.rows) { row in
                Button {
                    onSelect(row.id)
                } label: {
                    StationRow(row.summary, hours: row.hours,
                               highlight: SearchHighlight(text: content.text, match: row.hit.match))
                }
                .buttonStyle(.plain)
                .stationRowActions(row.summary.station, isFavorite: row.summary.isFavorite) {
                    onToggleFavorite(row.summary)
                }
                if row.id != content.rows.last?.id {
                    RowSeparator()
                }
            }
        }
    }
}

extension AppRouter {
    /// Pushes the detail on a tab's own stack (tabs layout, open Duo's left half).
    func detailPushBinding(on tab: AppTab) -> Binding<Bool> {
        Binding(get: { self.pushesDetail(on: tab) }, set: { self.isDetailPresented = $0 })
    }

    /// The sheet or inspector beside the map.
    var detailBesideMapBinding: Binding<Bool> {
        Binding(get: { self.presentsDetailBesideMap }, set: { self.isDetailPresented = $0 })
    }
}
