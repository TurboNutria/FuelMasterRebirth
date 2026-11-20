import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

extension LevelFilter {
    var title: Text {
        switch self {
        case .all: Text("Todas", bundle: .module)
        case .cheap: Text("Baratas", bundle: .module)
        case .average: Text("Medias", bundle: .module)
        case .expensive: Text("Caras", bundle: .module)
        }
    }
}
