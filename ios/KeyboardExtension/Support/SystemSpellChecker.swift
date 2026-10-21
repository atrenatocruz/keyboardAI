import UIKit
import KeyboardCore

/// UITextChecker in European Portuguese, plus the user's lexicon (contacts, text replacements) as known words.
final class SystemSpellChecker: SpellChecking {
    private let checker = UITextChecker()
    private let language: String
    private var lexicon: Set<String> = []

    init() {
        let available = UITextChecker.availableLanguages
        language = ["pt_PT", "pt-PT", "pt"].first(where: available.contains)
            ?? available.first(where: { $0.hasPrefix("pt") }) ?? "pt_PT"
    }

    func load(_ lexicon: UILexicon) {
        self.lexicon = Set(lexicon.entries.flatMap { [$0.userInput.lowercased(), $0.documentText.lowercased()] })
    }

    func isKnown(_ word: String) -> Bool {
        if lexicon.contains(word.lowercased()) || UITextChecker.hasLearnedWord(word) { return true }
        let range = NSRange(location: 0, length: (word as NSString).length)
        return checker.rangeOfMisspelledWord(in: word, range: range, startingAt: 0, wrap: false, language: language).location == NSNotFound
    }

    func guesses(for word: String) -> [String] {
        let range = NSRange(location: 0, length: (word as NSString).length)
        return checker.guesses(forWordRange: range, in: word, language: language) ?? []
    }

    func completions(for partial: String) -> [String] {
        let range = NSRange(location: 0, length: (partial as NSString).length)
        return checker.completions(forPartialWordRange: range, in: partial, language: language) ?? []
    }

    /// Called when the user keeps a word as typed, so it stops being flagged.
    func learn(_ word: String) {
        UITextChecker.learnWord(word)
    }
}
