import Foundation

/// Turns the ministry's capitalised text into display text (Bear note 05, round 10):
/// first letter of each word capitalised, Spanish particles in lower case, street types abbreviated.
public enum TextNormalizer {
    /// Brands whose usual spelling isn't plain title case.
    static let brandExceptions: [String: String] = [
        "BP": "BP", "Q8": "Q8", "AS24": "AS24", "E.LECLERC": "E.Leclerc", "GM": "GM",
    ]

    /// Lower-case words, except as the first word.
    static let particles: Set<String> = ["de", "del", "la", "las", "los", "el", "y", "e", "en", "a", "al", "d'", "i"]

    /// Street-type abbreviations, matched on the first word.
    static let streetTypes: [String: String] = [
        "CALLE": "C/", "CL": "C/", "C/": "C/", "CALLE.": "C/",
        "AVENIDA": "Av.", "AVDA.": "Av.", "AVDA": "Av.", "AV": "Av.", "AV.": "Av.", "AVINGUDA": "Av.",
        "CARRETERA": "Ctra.", "CR": "Ctra.", "CTRA.": "Ctra.", "CTRA": "Ctra.", "CRTA.": "Ctra.", "CRTA": "Ctra.",
        "PASEO": "P.º", "PLAZA": "Pl.", "GLORIETA": "Glta.", "TRAVESÍA": "Trav.", "TRAVESIA": "Trav.",
        "POLIGONO": "Pol.", "POLÍGONO": "Pol.", "PG": "Pol.", "PG.": "Pol.",
        "URBANIZACIÓN": "Urb.", "URBANIZACION": "Urb.",
        "AUTOVIA": "Autovía", "AUTOVÍA": "Autovía", "AU": "Autovía",
    ]

    public static func name(_ raw: String) -> String {
        let trimmed = collapse(raw)
        if let exception = brandExceptions[trimmed.uppercased()] { return exception }
        return titleCase(trimmed)
    }

    public static func address(_ raw: String) -> String {
        let trimmed = collapse(raw)
        guard !trimmed.isEmpty else { return "" }
        var words = trimmed.split(separator: " ").map(String.init)
        var prefix: String?
        if let first = words.first, let abbreviation = streetTypes[first.uppercased()] {
            prefix = abbreviation
            words.removeFirst()
        }
        var body = titleCase(words.joined(separator: " "))
        body = body.replacingOccurrences(of: #"\bKm\.?(?=\s|$|,)"#, with: "km", options: .regularExpression)
        body = body.replacingOccurrences(of: "S/N", with: "s/n", options: .caseInsensitive)
        guard let prefix else { return body }
        return body.isEmpty ? prefix : "\(prefix) \(body)"
    }

    static func collapse(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func titleCase(_ text: String) -> String {
        let words = text.split(separator: " ", omittingEmptySubsequences: true)
        return words.enumerated().map { index, word in
            let lower = word.lowercased()
            if index > 0, particles.contains(lower) { return lower }
            // Road codes and anything with digits stay as written: "N-340", "M-30", "A-6".
            if word.contains(where: \.isNumber) { return String(word) }
            return capitalizeSegments(lower)
        }.joined(separator: " ")
    }

    /// Capitalises each part split by hyphens, slashes, dots, apostrophes and opening brackets.
    static func capitalizeSegments(_ word: String) -> String {
        var result = ""
        var capitalizeNext = true
        for character in word {
            if capitalizeNext, character.isLetter {
                result += character.uppercased()
                capitalizeNext = false
            } else {
                result.append(character)
            }
            if "-/.'(".contains(character) { capitalizeNext = true }
        }
        return result
    }
}
