import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

/// The filter icon on its own, filled while a level filter is on (QA 2026-10-29: no label).
struct FilterIcon: View {
    let isActive: Bool

    var body: some View {
        Image(systemName: isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease")
            .frame(minWidth: 20)
    }
}
