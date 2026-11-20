import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

/// `.sideBySide` (standard iPhones in landscape): list and map side by side, detail as a sheet.
/// Plain panes rather than `ArrangementView`, which has no way to hide a pane from SwiftUI.
struct SideBySideRootView: View {
    @Bindable var router: AppRouter

    var body: some View {
        CollapsiblePanes(router: router, panelWidth: 320, detailInPane: false)
    }
}
