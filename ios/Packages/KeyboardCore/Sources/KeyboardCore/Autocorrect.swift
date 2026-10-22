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
    /// The word exactly as typed (shown in quotes; tapping it keeps it). nil → next-word predictions.
    public let typed: String?
    /// Alternatives (two while typing, three predictions), already matched to the typed capitalization.
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

    /// Above this many occurrences a word the dictionary doesn't know is treated as real usage (slang like "bro")
    /// and only corrected when the fix is overwhelmingly more common (e.g. "nao" → "não").
    static let commonUsageCount = 2000
    static let overwhelmingRatio = 20
    static let maxAutocorrectCost = 1.2
    /// Chat abbreviations people type on purpose; the system keyboard leaves these alone too.
    static let abbreviations: Set<String> = [
        "obg", "obgd", "tbm", "tb", "mt", "mto", "mts", "vc", "vcs", "pq", "q", "msg", "bj", "bjs", "bjo", "bjinhos",
        "kk", "kkk", "lol", "ok", "okay", "xau", "fds", "sff", "pf", "pfv", "ya", "yah", "nd", "cmg", "ctg", "dps",
        "hj", "tlm", "net", "td", "tds", "gg", "omg", "wtf", "btw", "pls", "thx", "ty", "np", "idk", "xd",
    ]

    public static func suggestions(for word: String, checker: SpellChecking, frequency: WordFrequency? = nil,
                                   rejected: Set<String> = []) -> Suggestions {
        if let frequency { return ranked(for: word, checker: checker, frequency: frequency, rejected: rejected) }
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

    private static func ranked(for word: String, checker: SpellChecking, frequency: WordFrequency,
                               rejected: Set<String>) -> Suggestions {
        let lower = word.lowercased()
        let typedCount = frequency.count(of: lower)
        var pool: [String] = []
        var autocorrection: String?

        if checker.isKnown(word) || abbreviations.contains(lower) {
            // Valid word: offer a more common accented spelling ("esta" → "está"), then completions.
            pool += frequency.accentVariants(of: lower)
                .filter { $0 != lower && frequency.count(of: $0) > typedCount && checker.isKnown($0) }
                .sorted { frequency.count(of: $0) > frequency.count(of: $1) }
        } else {
            let corrections = TypoModel.corrections(for: lower, frequency: frequency, extra: checker.guesses(for: word))
                .filter { checker.isKnown($0.word) }
            if let best = corrections.first, word.count > 1, !rejected.contains(lower), best.cost <= maxAutocorrectCost,
               typedCount < commonUsageCount || frequency.count(of: best.word) > overwhelmingRatio * typedCount {
                autocorrection = best.word
            }
            pool += corrections.prefix(4).map(\.word)
        }
        pool += frequency.completions(prefix: lower, limit: 8).filter { checker.isKnown($0) }
        if pool.isEmpty { pool = checker.completions(for: word) }

        let candidates = dedupe(pool, typed: word, limit: maxCandidates, first: autocorrection)
        return Suggestions(typed: word, candidates: candidates,
                           autocorrection: autocorrection.map { matchCase(of: word, $0) })
    }

    /// Suggestions for the next word when the cursor isn't on a word (after a space, punctuation or at the start).
    public static func predictions(after context: String?, checker: SpellChecking, frequency: WordFrequency,
                                   limit: Int = 3) -> Suggestions {
        let context = context ?? ""
        let atSentenceStart = KeyboardEngine.shouldCapitalize(context)
        let lastWord = context.split(whereSeparator: { !$0.isLetter }).last.map { $0.lowercased() }
        let words = frequency.mostFrequent(limit: limit) { $0 != lastWord && checker.isKnown($0) }
        let shown = atSentenceStart ? words.map { $0.prefix(1).uppercased() + $0.dropFirst() } : words
        return Suggestions(typed: nil, candidates: shown, autocorrection: nil)
    }

    private static func dedupe(_ pool: [String], typed: String, limit: Int, first: String?) -> [String] {
        var seen: Set<String> = [typed.lowercased()]
        var result: [String] = []
        for word in ([first].compactMap { $0 } + pool) where result.count < limit {
            let matched = matchCase(of: typed, word)
            if seen.insert(matched.lowercased()).inserted { result.append(matched) }
        }
        return result
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
