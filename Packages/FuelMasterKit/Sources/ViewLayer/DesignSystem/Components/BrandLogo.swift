import DomainLayer
import SwiftUI

/// A chain's round logo, as on the old FuelMaster's pins. The artwork is a white disc, so it reads
/// on any price colour and on the dark map alike.
struct BrandLogo: View {
    let brand: Brand
    let size: CGFloat

    var body: some View {
        Image("brand-\(brand.rawValue)", bundle: .module)
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
struct StationLogo: View {
    let brand: Brand?
    let size: CGFloat

    var body: some View {
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

#Preview("Brand logos") {
    LazyVGrid(columns: Array(repeating: GridItem(.fixed(44)), count: 6)) {
        ForEach(Brand.allCases, id: \.self) { BrandLogo(brand: $0, size: 40) }
    }
    .padding()
    .background(.gray)
}
