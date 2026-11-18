import CoreGraphics

/// Where the open iPhone Duo's fold crosses the root view (Bear note 02, "iPhone Duo"). Vertical
/// when the phone is held open like a book; horizontal when it's turned a quarter, flat or
/// standing on a table.
public struct FoldLine: Equatable, Sendable {
    public enum Axis: Sendable {
        case vertical, horizontal
    }

    public let frame: CGRect
    public let axis: Axis

    public init(frame: CGRect, axis: Axis) {
        self.frame = frame
        self.axis = axis
    }

    /// The first region that runs right across `size` through its middle third. Anything else (an
    /// off-centre region, a frame in an unexpected space) would make a broken pane, so it's ignored.
    /// A fold that's opened flat has no thickness, which still gives its axis.
    public init?(regions: [CGRect], in size: CGSize) {
        guard let fold = regions.lazy.compactMap({ Self.fold(from: $0, in: size) }).first else { return nil }
        self = fold
    }

    private static func fold(from region: CGRect, in size: CGSize) -> FoldLine? {
        if region.height > region.width, region.midX > size.width / 3, region.midX < size.width * 2 / 3 {
            return FoldLine(frame: region, axis: .vertical)
        }
        if region.width > region.height, region.midY > size.height / 3, region.midY < size.height * 2 / 3 {
            return FoldLine(frame: region, axis: .horizontal)
        }
        return nil
    }
}
