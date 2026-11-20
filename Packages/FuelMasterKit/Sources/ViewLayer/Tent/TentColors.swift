import DesignTokens
import SwiftUI

/// The sign's own colours (canvas: Tent Price Board). Always dark, whatever the app's look.
enum TentColors {
    static let background = Color(hex: 0x141518)
    /// The board's own text: the station's name, distance, status.
    static let text = Color(hex: 0xF2F2F2)
    static let plate = Color(hex: 0xF4F1EA)
    static let ink = Color(hex: 0x141518)
    /// Second line on a plate ("Más cercana abierta").
    static let inkSecondary = Color(hex: 0x4A4D53)
    static let window = Color(hex: 0x050505)
    static let windowBorder = Color(hex: 0x26282D)
    static let tile = Color(hex: 0x1D1F23)
    /// The change in cents on its tile.
    static let tileText = Color(hex: 0xD6D8DC)
    static let muted = Color(hex: 0xA9ACB2)
    static let open = Color(hex: 0x7FE0A3)
    static let closed = Color(hex: 0xFFA14A)
    static let priceLED = Color(hex: 0xFF3B2F)
    static let closedLED = Color(hex: 0xFFB000)
    static let down = Color(hex: 0x5CB8FF)
    static let up = Color(hex: 0xFFA14A)
}
