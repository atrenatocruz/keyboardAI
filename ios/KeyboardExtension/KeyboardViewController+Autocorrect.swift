import UIKit
import KeyboardCore

struct AutocorrectState {
    /// The correction just applied, so an immediate delete can put the original word back.
    var lastCorrection: (original: String, replacement: String, separator: String)?
    /// Words the user reverted or kept on purpose; never auto-corrected again this session.
    var rejected: Set<String> = []
}

extension KeyboardViewController {
    func setUpAutocorrect() {
        aiBar.onSuggestion = { [weak self] tap in self?.acceptSuggestion(tap) }
        requestSupplementaryLexicon { [weak self] lexicon in self?.spellChecker.load(lexicon) }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let url = Bundle.main.url(forResource: "pt_PT_words", withExtension: "txt"),
                  let text = try? String(contentsOf: url, encoding: .utf8) else { return }
            let frequency = WordFrequency(text: text)
            DispatchQueue.main.async {
                self?.wordFrequency = frequency
                self?.refreshSuggestions()
            }
        }
    }

    private var isAutocorrectAllowed: Bool {
        let proxy = textDocumentProxy
        if proxy.autocorrectionType == .no { return false }
        switch proxy.keyboardType ?? .default {
        case .URL, .emailAddress, .numberPad, .phonePad, .decimalPad, .asciiCapableNumberPad, .namePhonePad:
            return false
        default:
            return true
        }
    }

    /// The word right before the cursor, unless there's a selection or the cursor sits inside a word.
    private var wordBeforeCursor: String? {
        let proxy = textDocumentProxy
        if let selected = proxy.selectedText, !selected.isEmpty { return nil }
        if let after = proxy.documentContextAfterInput?.first, after.isLetter { return nil }
        return Autocorrect.currentWord(in: proxy.documentContextBeforeInput)
    }

    private func currentSuggestions() -> Suggestions? {
        guard isAutocorrectAllowed else { return nil }
        if let word = wordBeforeCursor {
            return Autocorrect.suggestions(for: word, checker: spellChecker, frequency: wordFrequency,
                                           rejected: autocorrectState.rejected)
        }
        guard let wordFrequency, textDocumentProxy.selectedText?.isEmpty ?? true else { return nil }
        return Autocorrect.predictions(after: textDocumentProxy.documentContextBeforeInput,
                                       checker: spellChecker, frequency: wordFrequency)
    }

    func refreshSuggestions() {
        guard !improveState.isImproving else { return }
        aiBar.showSuggestions(currentSuggestions())
    }

    /// Replaces a misspelled word right before a space/punctuation/return is typed.
    func autocorrectBefore(separator: String) {
        guard Autocorrect.triggers(on: separator),
              let suggestions = currentSuggestions(),
              let typed = suggestions.typed,
              let fix = suggestions.autocorrection else { return }
        apply(Autocorrect.replaceActions(word: typed, with: fix))
        autocorrectState.lastCorrection = (typed, fix, separator)
    }

    /// Delete right after an autocorrection restores what was typed (and stops correcting that word).
    func undoAutocorrect(_ correction: (original: String, replacement: String, separator: String)?) -> Bool {
        guard let correction,
              textDocumentProxy.documentContextBeforeInput?.hasSuffix(correction.replacement + correction.separator) == true
        else { return false }
        apply([.deleteBackward(correction.replacement.count + correction.separator.count), .insert(correction.original)])
        autocorrectState.rejected.insert(correction.original.lowercased())
        lastSyncedContext = nil
        syncWithDocument()
        return true
    }

    private func acceptSuggestion(_ tap: AIBarView.SuggestionTap) {
        guard !improveState.isImproving else { return }
        willHandleKeyInput()
        autocorrectState.lastCorrection = nil
        haptics.keyTap()
        switch tap {
        case .keep(let word):
            guard wordBeforeCursor == word else { return }
            spellChecker.learn(word)
            autocorrectState.rejected.insert(word.lowercased())
        case .replace(let word):
            guard let typed = wordBeforeCursor else { return }
            apply(Autocorrect.replaceActions(word: typed, with: word))
        case .insert(let word):
            // Predictions follow a space; after punctuation like "," add the space first.
            if let last = textDocumentProxy.documentContextBeforeInput?.last, !last.isWhitespace {
                apply([.insert(" ")])
            }
            apply([.insert(word)])
        }
        perform(.space)
    }
}
