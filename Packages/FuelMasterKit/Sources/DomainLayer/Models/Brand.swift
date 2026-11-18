import Foundation

/// A chain whose logo the app carries, recognised from a station's sign ("REPSOL", "E.LECLERC
/// ALCOBENDAS", "Bonàrea"). Signs the app has no logo for give no brand.
public enum Brand: String, CaseIterable, Sendable {
    case agla, alas, alcampo, autonet, avia, ballenoil, bonarea, bp, byEnergy, campsa, carrefour, cepsa
    case costco, disa, eleclerc, eroski, esclatoil, galp, gasexpress, ham, meroil, moeve, naturgy, nieves
    case petrocat, petromiralles, petronor, petroprix, plenoil, q8, repsol, shell, supeco, tamoil, valcarce

    /// Whole words (or runs of words) of the sign that name the chain, in capitals without accents.
    /// Matching whole words keeps "AVIA" out of "AUTOVIA" and "HAM" out of "GRAHAM".
    var signs: [[String]] {
        switch self {
        case .agla: [["AGLA"]]
        case .alas: [["ALAS"]]
        case .alcampo: [["ALCAMPO"]]
        case .autonet: [["AUTONET"], ["AUTONETOIL"]]
        case .avia: [["AVIA"]]
        case .ballenoil: [["BALLENOIL"]]
        case .bonarea: [["BONAREA"], ["BON", "AREA"]]
        case .bp: [["BP"]]
        case .byEnergy: [["BY", "ENERGY"], ["BYENERGY"]]
        case .campsa: [["CAMPSA"]]
        case .carrefour: [["CARREFOUR"]]
        case .cepsa: [["CEPSA"]]
        case .costco: [["COSTCO"]]
        case .disa: [["DISA"]]
        case .eleclerc: [["E", "LECLERC"], ["LECLERC"]]
        case .eroski: [["EROSKI"]]
        case .esclatoil: [["ESCLATOIL"], ["ESCLAT"]]
        case .galp: [["GALP"]]
        case .gasexpress: [["GASEXPRESS"], ["GAS", "EXPRESS"]]
        case .ham: [["HAM"]]
        case .meroil: [["MEROIL"]]
        case .moeve: [["MOEVE"]]
        case .naturgy: [["NATURGY"]]
        case .nieves: [["NIEVES"]]
        case .petrocat: [["PETROCAT"]]
        case .petromiralles: [["PETROMIRALLES"]]
        case .petronor: [["PETRONOR"]]
        case .petroprix: [["PETROPRIX"]]
        case .plenoil: [["PLENOIL"]]
        case .q8: [["Q8"]]
        case .repsol: [["REPSOL"]]
        case .shell: [["SHELL"]]
        case .supeco: [["SUPECO"]]
        case .tamoil: [["TAMOIL"]]
        case .valcarce: [["VALCARCE"]]
        }
    }

    /// The first chain named in the sign, reading left to right.
    public init?(sign: String) {
        let words = sign
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es"))
            .uppercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
        guard !words.isEmpty else { return nil }
        for start in words.indices {
            for brand in Self.allCases {
                for run in brand.signs where words[start...].starts(with: run) {
                    self = brand
                    return
                }
            }
        }
        return nil
    }
}

extension Station {
    /// The chain whose logo goes on this station's pin, if the app has one.
    public var brand: Brand? { Brand(sign: name) }
}
