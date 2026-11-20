import DesignTokens
import SwiftUI

/// Seven-segment LED text, as on a forecourt price sign (canvas: Tent Price Board). Unlit
/// segments stay faintly visible ("ghost" segments) and lit ones glow. Supports digits, "-", the
/// letters a sign can spell (A b C d E F H L n O o P r S t U), ".", ":" and spaces. Localised sign
/// text must stick to these.
struct SevenSegmentText: View {
    /// One character per glyph. With `smallLast`, the last digit is drawn smaller and raised, the
    /// way signs show the third decimal ("1.45⁹").
    let text: String
    /// Width of one segment stroke-unit in points; a digit is 4.6 × 8 units.
    let unit: CGFloat
    let color: Color
    var smallLast = false

    var body: some View {
        let glyphs = Array(text)
        HStack(alignment: .top, spacing: unit) {
            ForEach(Array(glyphs.enumerated()), id: \.offset) { index, character in
                let isLast = index == glyphs.count - 1
                switch character {
                case ".":
                    Circle().fill(color)
                        .frame(width: unit, height: unit)
                        .frame(height: unit * 8, alignment: .bottom)
                        .padding(.horizontal, -unit * 0.3)
                case ":":
                    VStack(spacing: unit * 2.2) {
                        Circle().fill(color).frame(width: unit, height: unit)
                        Circle().fill(color).frame(width: unit, height: unit)
                    }
                    .frame(height: unit * 8)
                case " ":
                    Color.clear.frame(width: unit * 2.4, height: unit * 8)
                default:
                    SevenSegmentGlyph(segments: Self.segments(for: character), color: color)
                        .frame(width: unit * (smallLast && isLast ? 0.7 : 1) * 4.6,
                               height: unit * (smallLast && isLast ? 0.7 : 1) * 8)
                }
            }
        }
        .shadow(color: color.opacity(0.6), radius: unit * 0.6)
        .accessibilityHidden(true)
    }

    /// Lit segments, named the usual way: a top, b top right, c bottom right, d bottom, e bottom
    /// left, f top left, g middle.
    static func segments(for character: Character) -> Set<Character> {
        let map: [Character: String] = [
            "0": "abcdef", "1": "bc", "2": "abdeg", "3": "abcdg", "4": "bcfg", "5": "acdfg", "6": "acdefg",
            "7": "abc", "8": "abcdefg", "9": "abcdfg", "-": "g",
            "A": "abcefg", "b": "cdefg", "C": "adef", "d": "bcdeg", "E": "adefg", "F": "aefg", "H": "bcefg",
            "L": "def", "n": "ceg", "O": "abcdef", "o": "cdeg", "P": "abefg", "r": "eg", "S": "acdfg", "t": "defg",
            "U": "bcdef",
        ]
        return Set(map[character] ?? "")
    }
}

/// One digit: the seven segments as tapered bars, slanted 6° like an LED sign.
struct SevenSegmentGlyph: View {
    let segments: Set<Character>
    let color: Color

    /// Unlit segments are still faintly visible, as on a real sign.
    static let ghostOpacity = 0.09

    var body: some View {
        Canvas { context, size in
            let u = size.width / 4.6
            let skew = CGAffineTransform(a: 1, b: 0, c: -tan(6 * .pi / 180), d: 1, tx: tan(6 * .pi / 180) * size.height / 2, ty: 0)
            for (name, rect) in Self.layout {
                let path = Self.bar(rect: CGRect(x: rect.minX * u, y: rect.minY * u, width: rect.width * u, height: rect.height * u),
                                    tip: 0.45 * u).applying(skew)
                context.fill(path, with: .color(color.opacity(segments.contains(name) ? 1 : Self.ghostOpacity)))
            }
        }
    }

    /// Segment rectangles in units of a 4.6 × 8 digit (the board's CSS geometry).
    static let layout: [(Character, CGRect)] = [
        ("a", CGRect(x: 0.5, y: 0, width: 3.6, height: 0.9)),
        ("g", CGRect(x: 0.5, y: 3.55, width: 3.6, height: 0.9)),
        ("d", CGRect(x: 0.5, y: 7.1, width: 3.6, height: 0.9)),
        ("f", CGRect(x: 0, y: 0.5, width: 0.9, height: 3.1)),
        ("b", CGRect(x: 3.7, y: 0.5, width: 0.9, height: 3.1)),
        ("e", CGRect(x: 0, y: 4.4, width: 0.9, height: 3.1)),
        ("c", CGRect(x: 3.7, y: 4.4, width: 0.9, height: 3.1)),
    ]

    /// A bar with pointed ends, horizontal or vertical depending on its shape.
    static func bar(rect: CGRect, tip: CGFloat) -> Path {
        Path { path in
            if rect.width > rect.height {
                path.addLines([
                    CGPoint(x: rect.minX, y: rect.midY), CGPoint(x: rect.minX + tip, y: rect.minY),
                    CGPoint(x: rect.maxX - tip, y: rect.minY), CGPoint(x: rect.maxX, y: rect.midY),
                    CGPoint(x: rect.maxX - tip, y: rect.maxY), CGPoint(x: rect.minX + tip, y: rect.maxY),
                ])
            } else {
                path.addLines([
                    CGPoint(x: rect.midX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY + tip),
                    CGPoint(x: rect.maxX, y: rect.maxY - tip), CGPoint(x: rect.midX, y: rect.maxY),
                    CGPoint(x: rect.minX, y: rect.maxY - tip), CGPoint(x: rect.minX, y: rect.minY + tip),
                ])
            }
            path.closeSubpath()
        }
    }
}

#Preview("LED") {
    VStack(spacing: 20) {
        SevenSegmentText(text: "1.459", unit: 9, color: Color(hex: 0xFF3B2F), smallLast: true)
        SevenSegmentText(text: "CErrAdA", unit: 9, color: Color(hex: 0xFFB000))
        SevenSegmentText(text: "AbrE 06:00", unit: 6, color: Color(hex: 0xFFB000))
    }
    .padding(30)
    .background(Color(hex: 0x050505))
}
