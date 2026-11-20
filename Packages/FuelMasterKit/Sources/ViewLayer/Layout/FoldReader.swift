import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

/// Where the open iPhone Duo's fold crosses this view, from the system's reserved regions. Nil on
/// iOS 26 and on screens without one.
struct FoldReader: View {
    @Binding var fold: FoldLine?

    var body: some View {
        Color.clear
            .onGeometryChange(for: FoldLine?.self) { proxy in
                let size = proxy.size
                #if DEBUG
                // `-FMFakeFold YES` pretends there's a hinge down the middle, to try the open-Duo
                // layout on an iPad simulator; `-FMFakeFoldAcross YES` turns it a quarter.
                if UserDefaults.standard.bool(forKey: "FMFakeFold") {
                    if UserDefaults.standard.bool(forKey: "FMFakeFoldAcross") {
                        return FoldLine(frame: CGRect(x: 0, y: size.height / 2, width: size.width, height: 0),
                                        axis: .horizontal)
                    }
                    return FoldLine(frame: CGRect(x: size.width / 2, y: 0, width: 0, height: size.height),
                                    axis: .vertical)
                }
                #endif
                #if os(iOS)
                guard #available(iOS 27.1, *) else { return nil }
                // Inactive ones too: opened flat, the fold has no thickness but stays where it was,
                // so bending and flattening the phone keeps the same layout.
                let regions = proxy.reservedRegions(kind: .division, options: .includeInactive)
                    .map { (region: ReservedRegion) in region.frame }
                return FoldLine(regions: regions, in: size)
                #else
                return nil
                #endif
            } action: { fold = $0 }
    }
}
