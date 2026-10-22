import Foundation

/// Word counts from a "word count" per-line list (most frequent first), used to rank corrections,
/// completions and predictions. Built once per keyboard session; lookups are dictionary/binary-search.
public final class WordFrequency: @unchecked Sendable {
    private var counts: [String: Int] = [:]
    private var sortedWords: [String] = []
    private var byFolded: [String: [String]] = [:]
    private var ranked: [String] = []

    public init(text: String) {
        var entries: [(String, Int)] = []
        for line in text.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count == 2, let count = Int(parts[1]) else { continue }
            let word = parts[0].lowercased()
            guard counts[word] == nil else { continue }
            counts[word] = count
            entries.append((word, count))
        }
        ranked = entries.sorted { $0.1 > $1.1 }.map(\.0)
        sortedWords = counts.keys.sorted()
        for word in sortedWords { byFolded[Self.fold(word), default: []].append(word) }
    }

    public func count(of word: String) -> Int { counts[word.lowercased()] ?? 0 }

    /// Words starting with `prefix` (excluding the prefix itself), most frequent first.
    public func completions(prefix: String, limit: Int) -> [String] {
        let prefix = prefix.lowercased()
        guard !prefix.isEmpty else { return [] }
        var low = 0, high = sortedWords.count
        while low < high {
            let mid = (low + high) / 2
            if sortedWords[mid] < prefix { low = mid + 1 } else { high = mid }
        }
        var matches: [String] = []
        var i = low
        while i < sortedWords.count, sortedWords[i].hasPrefix(prefix) {
            if sortedWords[i] != prefix { matches.append(sortedWords[i]) }
            i += 1
        }
        return Array(matches.sorted { count(of: $0) > count(of: $1) }.prefix(limit))
    }

    /// Every listed word that differs from `word` only in accents (e.g. "nao" → ["nao", "não"]).
    public func accentVariants(of word: String) -> [String] { byFolded[Self.fold(word)] ?? [] }

    /// Most frequent words passing `include`, in frequency order.
    public func mostFrequent(limit: Int, where include: (String) -> Bool) -> [String] {
        var result: [String] = []
        for word in ranked where include(word) {
            result.append(word)
            if result.count == limit { break }
        }
        return result
    }

    static func fold(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }
}

/// Typing-error model: which single edits turn the typed word into a listed word, and how "cheap" each edit is.
/// Accent slips and neighbouring keys are cheap; random substitutions are expensive.
enum TypoModel {
    struct Correction { let word: String; let cost: Double; let score: Double }

    private static let alphabet = Array("abcdefghijklmnopqrstuvwxyzáàâãéêíóôõúüç")
    private static let costWeight = 2.5
    private static let adjacency: [Character: Set<Character>] = {
        let rows: [[Character]] = ["qwertyuiop", "asdfghjkl", "zxcvbnm"].map { Array($0) }
        let offsets: [Double] = [0, 0.5, 1.5]
        var map: [Character: Set<Character>] = [:]
        for (r, row) in rows.enumerated() {
            for (i, key) in row.enumerated() {
                let x = Double(i) + offsets[r]
                for (r2, row2) in rows.enumerated() where abs(r2 - r) <= 1 {
                    for (j, other) in row2.enumerated() where other != key && abs(Double(j) + offsets[r2] - x) <= 1 {
                        map[key, default: []].insert(other)
                    }
                }
            }
        }
        return map
    }()

    static func base(_ c: Character) -> Character { WordFrequency.fold(String(c)).first ?? c }

    static func isAdjacent(_ a: Character, _ b: Character) -> Bool {
        adjacency[base(a)]?.contains(base(b)) ?? false
    }

    /// Ranked best-first by log-frequency minus weighted edit cost.
    static func corrections(for word: String, frequency: WordFrequency, extra: [String]) -> [Correction] {
        let word = word.lowercased()
        let chars = Array(word)
        guard !chars.isEmpty, chars.count <= 24 else { return [] }
        var costs: [String: Double] = [:]
        let extraSet = Set(extra.map { $0.lowercased() })

        func add(_ candidate: String, _ cost: Double) {
            for variant in frequency.accentVariants(of: candidate) where variant != word {
                let total = cost + (variant == candidate ? 0 : 0.25)
                costs[variant] = min(costs[variant] ?? .infinity, total)
            }
            if candidate != word, extraSet.contains(candidate) {
                costs[candidate] = min(costs[candidate] ?? .infinity, max(cost, 1.5))
            }
        }

        add(word, 0)   // accent-only fixes ("nao" → "não")
        for i in chars.indices {
            var c = chars; c.remove(at: i)
            // A doubled key press ("coisaa") is the cheapest deletion.
            let doubled = (i > 0 && chars[i - 1] == chars[i]) || (i + 1 < chars.count && chars[i + 1] == chars[i])
            add(String(c), doubled ? 0.5 : 1.0)
        }
        for i in chars.indices.dropLast() {
            var c = chars; c.swapAt(i, i + 1)
            add(String(c), 0.7)
        }
        for i in chars.indices {
            for letter in alphabet where letter != chars[i] {
                var c = chars; c[i] = letter
                let cost = base(letter) == base(chars[i]) ? 0.25 : (isAdjacent(letter, chars[i]) ? 0.6 : 1.2)
                add(String(c), cost)
            }
        }
        for i in 0...chars.count {
            for letter in alphabet {
                var c = chars; c.insert(letter, at: i)
                let neighbours = [i > 0 ? chars[i - 1] : nil, i < chars.count ? chars[i] : nil].compactMap { $0 }
                let cost = neighbours.contains(letter) ? 0.6
                    : (neighbours.contains { isAdjacent($0, letter) } ? 0.8 : 1.0)
                add(String(c), cost)
            }
        }
        for guess in extraSet where costs[guess] == nil && guess != word { costs[guess] = 1.5 }

        return costs.map { candidate, cost in
            Correction(word: candidate, cost: cost,
                       score: log(Double(frequency.count(of: candidate)) + 1) - costWeight * cost)
        }
        .sorted { $0.score != $1.score ? $0.score > $1.score : $0.word < $1.word }
    }
}
