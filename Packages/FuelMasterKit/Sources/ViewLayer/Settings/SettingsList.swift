import SwiftUI

/// The plain list shared by Ajustes, Apariencia and Fuente y aviso legal: rows straight on the
/// background with hairlines, 20 pt from the edges, as in Gasolineras and Favoritos.
struct SettingsList<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        List { content }
            .listStyle(.plain)
            // Rows size themselves (see `SettingsRow`), so spacer and title rows can be short.
            .environment(\.defaultMinListRowHeight, 0)
            .scrollContentBackground(.hidden)
            .background(ColorTokens.background)
    }
}

/// A group of rows under a grey title. The space above the title does the grouping, so there
/// are no hairlines above the first row or below the last.
struct SettingsSection<Content: View>: View {
    let title: Text?
    var spacingAbove: CGFloat = 32
    @ViewBuilder let content: Content

    var body: some View {
        Section {
            Group {
                if let title {
                    title
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(ColorTokens.textSecondary)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, spacingAbove)
                        .padding(.bottom, 4)
                } else {
                    Color.clear.frame(height: spacingAbove).accessibilityHidden(true)
                }
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            Group(subviews: content) { rows in
                ForEach(rows) { row in
                    row.modifier(SettingsRow(separatorAbove: row.id != rows.first?.id,
                                             separatorBelow: row.id != rows.last?.id))
                }
            }
        }
        .listSectionSeparator(.hidden)
    }
}

extension SettingsSection {
    init(_ title: Text?, spacingAbove: CGFloat = 32, @ViewBuilder content: () -> Content) {
        self.title = title
        self.spacingAbove = spacingAbove
        self.content = content()
    }
}

/// One row: at least 56 pt tall, full width, hairlines that stop at the 20 pt margin on both sides.
struct SettingsRow: ViewModifier {
    var separatorAbove = true
    var separatorBelow = true

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            .alignmentGuide(.listRowSeparatorTrailing) { $0[.trailing] }
            .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparatorTint(ColorTokens.separator)
            .listRowSeparator(separatorAbove ? .visible : .hidden, edges: .top)
            .listRowSeparator(separatorBelow ? .visible : .hidden, edges: .bottom)
    }
}
