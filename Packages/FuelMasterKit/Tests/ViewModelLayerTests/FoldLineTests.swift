import CoreGraphics
import Testing
import ViewModelLayer

@Suite("Fold line")
struct FoldLineTests {
    private let open = CGSize(width: 890, height: 626)
    private let turned = CGSize(width: 626, height: 890)

    @Test func aFoldDownTheMiddleIsVertical() {
        let fold = FoldLine(regions: [CGRect(x: 437, y: 0, width: 16, height: 626)], in: open)
        #expect(fold?.axis == .vertical)
        #expect(fold?.frame.minX == 437)
    }

    @Test func aFoldAcrossTheMiddleIsHorizontal() {
        let fold = FoldLine(regions: [CGRect(x: 0, y: 437, width: 626, height: 16)], in: turned)
        #expect(fold?.axis == .horizontal)
        #expect(fold?.frame.minY == 437)
    }

    @Test func aFlatFoldKeepsItsAxis() {
        // Opened flat, the fold is inactive and has no thickness, but stays where it was.
        #expect(FoldLine(regions: [CGRect(x: 445, y: 0, width: 0, height: 626)], in: open)?.axis == .vertical)
        #expect(FoldLine(regions: [CGRect(x: 0, y: 445, width: 626, height: 0)], in: turned)?.axis == .horizontal)
    }

    @Test func offCentreOrEmptyRegionsAreIgnored() {
        #expect(FoldLine(regions: [CGRect(x: 100, y: 0, width: 16, height: 626)], in: open) == nil)
        #expect(FoldLine(regions: [CGRect(x: 0, y: 80, width: 626, height: 16)], in: turned) == nil)
        #expect(FoldLine(regions: [.zero], in: open) == nil)
        #expect(FoldLine(regions: [], in: open) == nil)
    }

    @Test func theFirstUsableRegionWins() {
        let fold = FoldLine(regions: [CGRect(x: 10, y: 0, width: 4, height: 626),
                                      CGRect(x: 437, y: 0, width: 16, height: 626)], in: open)
        #expect(fold?.frame.minX == 437)
    }
}
