import DomainLayer
import SwiftUI
import ViewModelLayer

/// Everything outside a pin that changes how it's drawn. A change redraws every image.
struct PinLook: Equatable {
    let priceScale: PriceScale
    let locale: Locale
    let colorScheme: ColorScheme
    let contrast: ColorSchemeContrast
    let typeSize: DynamicTypeSize
    let differentiateWithoutColor: Bool
    let displayScale: CGFloat

    init(_ environment: EnvironmentValues) {
        priceScale = environment.priceScale
        locale = environment.displayFormat.locale
        colorScheme = environment.colorScheme
        contrast = environment.colorSchemeContrast
        typeSize = environment.dynamicTypeSize
        differentiateWithoutColor = environment.accessibilityDifferentiateWithoutColor
        displayScale = environment.displayScale
    }
}
