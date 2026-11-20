import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

/// Where the detail is shown (Bear note 02): pushed in the tabs layout, a sheet side by side,
/// an inspector in a wide split, and a pane over the map's half in a narrow one (the open Duo).
/// Pushed screens get the system back button; the others a close button.
enum DetailPresentation {
    case push
    case sheet
    case inspector
    case pane
}
