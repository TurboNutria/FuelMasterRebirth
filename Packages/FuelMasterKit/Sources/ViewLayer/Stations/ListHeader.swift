import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

/// "Cerca de ti · 3 km · 23 estaciones".
struct ListHeader: View {
    let viewModel: StationListViewModel

    @Environment(\.displayFormat) private var format
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Text(area)
            .font(.footnote)
            .foregroundStyle(ColorTokens.textSecondary)
    }

    private var area: String {
        let count = viewModel.state.content?.rows.count
        if typeSize.isAccessibilitySize, let count {
            return String(localized: "\(count) cerca", bundle: .module, comment: "Header at very large text sizes")
        }
        var parts: [String] = []
        switch viewModel.scope {
        case .nearby(let radius):
            parts.append(String(localized: "Cerca de ti", bundle: .module))
            parts.append(format.radius(meters: radius))
        case .province(let name):
            parts.append(String(localized: "En \(name)", bundle: .module, comment: "Header without location: En Madrid"))
        case nil:
            break
        }
        if let count { parts.append(String(localized: "\(count) estaciones", bundle: .module)) }
        return parts.joined(separator: " · ")
    }
}
