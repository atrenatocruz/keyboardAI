public enum Accents {
    private static let table: [String: [String]] = [
        "a": ["á", "à", "â", "ã", "ª"],
        "e": ["é", "ê", "è"],
        "i": ["í"],
        "o": ["ó", "ô", "õ", "º"],
        "u": ["ú", "ü"],
        "c": ["ç"],
        "n": ["ñ"],
    ]

    public static func variants(for base: String, uppercase: Bool) -> [String] {
        guard let list = table[base.lowercased()] else { return [] }
        guard uppercase else { return list }
        return list.map { $0 == "ª" || $0 == "º" ? $0 : $0.uppercased() }
    }
}
