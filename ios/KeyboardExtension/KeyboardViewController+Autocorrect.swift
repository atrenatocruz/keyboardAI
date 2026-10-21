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
        aiBar.onSuggestion = { [weak self] word, isTyped in self?.acceptSuggestion(word, isTyped: isTyped) }
        requestSupplementaryLexicon { [weak self] lexicon in self?.spellChecker.load(lexicon) }
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
        guard isAutocorrectAllowed, let word = wordBeforeCursor else { return nil }
        return Autocorrect.suggestions(for: word, checker: spellChecker, rejected: autocorrectState.rejected)
    }

    func refreshSuggestions() {
        guard !improveState.isImproving else { return }
        aiBar.showSuggestions(currentSuggestions())
    }

    /// Replaces a misspelled word right before a space/punctuation/return is typed.
    func autocorrectBefore(separator: String) {
        guard Autocorrect.triggers(on: separator),
              let suggestions = currentSuggestions(),
              let fix = suggestions.autocorrection else { return }
        apply(Autocorrect.replaceActions(word: suggestions.typed, with: fix))
        autocorrectState.lastCorrection = (suggestions.typed, fix, separator)
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

    private func acceptSuggestion(_ word: String, isTyped: Bool) {
        guard !improveState.isImproving, let typed = wordBeforeCursor else { return }
        willHandleKeyInput()
        autocorrectState.lastCorrection = nil
        haptics.keyTap()
        if isTyped {
            spellChecker.learn(typed)
            autocorrectState.rejected.insert(typed.lowercased())
        } else {
            apply(Autocorrect.replaceActions(word: typed, with: word))
        }
        perform(.space)
    }
}
