import DesignTokens
#if os(iOS)
import DomainLayer
import SwiftUI
import ViewModelLayer
import WidgetKit

extension LocalizedStringResource.BundleDescription {
    /// This package target's bundle, which holds the widgets' String Catalog.
    static var widgetViewLayer: Self { .atURL(Bundle.module.bundleURL) }
}
#endif
