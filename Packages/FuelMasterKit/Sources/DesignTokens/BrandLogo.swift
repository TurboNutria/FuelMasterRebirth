import DomainLayer
import SwiftUI

/// A chain's round logo, as on the old FuelMaster's pins. The artwork is a white disc, so it reads
/// on any price colour and on the dark map alike.
public struct BrandLogo: View {
    let brand: Brand
    let size: CGFloat

    public init(brand: Brand, size: CGFloat) {
        self.brand = brand
        self.size = size
    }

    public var body: some View {
        Image(brand: brand)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(.circle)
            .accessibilityHidden(true)
    }
}

/// A row's logo: the chain's, or a plain pump on a grey disc for signs the app has no logo for,
/// so names stay lined up down the list.
public struct StationLogo: View {
    let brand: Brand?
    let size: CGFloat

    public init(brand: Brand?, size: CGFloat) {
        self.brand = brand
        self.size = size
    }

    public var body: some View {
        if let brand {
            BrandLogo(brand: brand, size: size)
        } else {
            Image(systemName: "fuelpump.fill")
                .font(.system(size: size * 0.42))
                .foregroundStyle(ColorTokens.textSecondary)
                .frame(width: size, height: size)
                .background(ColorTokens.cell, in: .circle)
                .accessibilityHidden(true)
        }
    }
}

extension Image {
    /// The chain's logo from this target's asset catalogue. Other targets must use this rather
    /// than `Image(_:bundle: .module)`, which would look in their own bundle.
    public init(brand: Brand) {
        self.init("brand-\(brand.rawValue)", bundle: .module)
    }
}

#Preview("Brand logos") {
    LazyVGrid(columns: Array(repeating: GridItem(.fixed(44)), count: 6)) {
        ForEach(Brand.allCases, id: \.self) { BrandLogo(brand: $0, size: 40) }
    }
    .padding()
    .background(.gray)
}
