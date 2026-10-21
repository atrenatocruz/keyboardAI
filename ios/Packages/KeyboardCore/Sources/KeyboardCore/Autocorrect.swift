/// Dictionary lookups behind autocorrect. The keyboard backs this with UITextChecker (pt_PT);
/// tests use a fake so the suggestion rules stay platform-independent.
public protocol SpellChecking {
    func isKnown(_ word: String) -> Bool
    /// Spelling corrections, best first.
    func guesses(for word: String) -> [String]
    /// Words that start with `partial`, most likely first.
    func completions(for partial: String) -> [String]
}

public struct Suggestions: Equatable, Sendable {
    /// The word exactly as typed (shown in quotes; tapping it keeps it).
    public let typed: String
    /// Up to two alternatives, already matched to the typed capitalization.
    public let candidates: [String]
    /// Applied automatically on space/punctuation; always `candidates.first` when present.
    public let autocorrection: String?
}

public enum Autocorrect {
    static let maxCandidates = 2
    private static let wordPunctuation: Set<Character> = ["'", "’", "-"]
    private static let triggerCharacters: Set<String> = [" ", "\n", ".", ",", "?", "!", ";", ":"]

    /// The word being typed right before the cursor, or nil when the cursor isn't at the end of a plain word
    /// (e.g. after a space, or inside something with digits/@/ like a code, handle or URL).
    public static func currentWord(in context: String?) -> String? {
        guard let context, !context.isEmpty else { return nil }
        let word = String(context.reversed().prefix { $0.isLetter || wordPunctuation.contains($0) }.reversed())
        guard word.contains(where: \.isLetter) else { return nil }
        let before = context.dropLast(word.count).last
        if let before, before.isNumber || before.isLetter || "@/_#".contains(before) { return nil }
        return word
    }

    public static func suggestions(for word: String, checker: SpellChecking, rejected: Set<String> = []) -> Suggestions {
        let isKnown = checker.isKnown(word)
        var raw = isKnown ? [] : checker.guesses(for: word)
        let isCorrection = !raw.isEmpty
        if raw.isEmpty { raw = checker.completions(for: word) }

        var seen: Set<String> = [word.lowercased()]
        var candidates: [String] = []
        for guess in raw where candidates.count < maxCandidates {
            let matched = matchCase(of: word, guess)
            if seen.insert(matched.lowercased()).inserted { candidates.append(matched) }
        }

        let canCorrect = isCorrection && word.count > 1 && !rejected.contains(word.lowercased())
        return Suggestions(typed: word, candidates: candidates, autocorrection: canCorrect ? candidates.first : nil)
    }

    public static func matchCase(of typed: String, _ candidate: String) -> String {
        if typed.count > 1, typed == typed.uppercased(), typed != typed.lowercased() { return candidate.uppercased() }
        if let first = typed.first, first.isUppercase { return candidate.prefix(1).uppercased() + candidate.dropFirst() }
        return candidate
    }

    public static func replaceActions(word: String, with replacement: String) -> [TextAction] {
        [.deleteBackward(word.count), .insert(replacement)]
    }

    /// Characters that end a word and apply the pending autocorrection first.
    public static func triggers(on text: String) -> Bool { triggerCharacters.contains(text) }
}
