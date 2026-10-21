import XCTest
@testable import KeyboardCore

private struct FakeChecker: SpellChecking {
    var known: Set<String> = []
    var guesses: [String: [String]] = [:]
    var completions: [String: [String]] = [:]

    func isKnown(_ word: String) -> Bool { known.contains(word.lowercased()) }
    func guesses(for word: String) -> [String] { guesses[word.lowercased()] ?? [] }
    func completions(for partial: String) -> [String] { completions[partial.lowercased()] ?? [] }
}

final class AutocorrectTests: XCTestCase {
    func testCurrentWordIsTrailingLetters() {
        XCTAssertEqual(Autocorrect.currentWord(in: "Ola tudoe"), "tudoe")
        XCTAssertEqual(Autocorrect.currentWord(in: "diz-me"), "diz-me")
        XCTAssertEqual(Autocorrect.currentWord(in: "d'água"), "d'água")
        XCTAssertNil(Autocorrect.currentWord(in: "Ola "))
        XCTAssertNil(Autocorrect.currentWord(in: ""))
        XCTAssertNil(Autocorrect.currentWord(in: nil))
        XCTAssertNil(Autocorrect.currentWord(in: "abc123"))
    }

    func testMisspelledWordGetsCorrectionInTheMiddle() {
        let checker = FakeChecker(guesses: ["tudoe": ["tudo", "todos", "tido"]])
        let s = Autocorrect.suggestions(for: "tudoe", checker: checker)
        XCTAssertEqual(s.typed, "tudoe")
        XCTAssertEqual(s.autocorrection, "tudo")
        XCTAssertEqual(s.candidates, ["tudo", "todos"])
    }

    func testKnownWordIsNotCorrectedAndOffersCompletions() {
        let checker = FakeChecker(known: ["tud", "tudo"], completions: ["tud": ["tudo", "tudinho", "tudão"]])
        let s = Autocorrect.suggestions(for: "tud", checker: checker)
        XCTAssertNil(s.autocorrection)
        XCTAssertEqual(s.candidates, ["tudo", "tudinho"])
    }

    func testUnknownWordWithoutGuessesFallsBackToCompletions() {
        let checker = FakeChecker(completions: ["obrig": ["obrigado", "obrigada"]])
        let s = Autocorrect.suggestions(for: "obrig", checker: checker)
        XCTAssertNil(s.autocorrection)
        XCTAssertEqual(s.candidates, ["obrigado", "obrigada"])
    }

    func testSingleLettersAreNeverCorrected() {
        let checker = FakeChecker(guesses: ["q": ["que"]])
        XCTAssertNil(Autocorrect.suggestions(for: "q", checker: checker).autocorrection)
    }

    func testRejectedWordIsNotCorrectedAgain() {
        let checker = FakeChecker(guesses: ["bro": ["boro"]])
        let s = Autocorrect.suggestions(for: "bro", checker: checker, rejected: ["bro"])
        XCTAssertNil(s.autocorrection)
    }

    func testCandidatesMatchTypedCapitalization() {
        let checker = FakeChecker(guesses: ["nao": ["não"]])
        XCTAssertEqual(Autocorrect.suggestions(for: "Nao", checker: checker).autocorrection, "Não")
        XCTAssertEqual(Autocorrect.suggestions(for: "NAO", checker: checker).autocorrection, "NÃO")
        XCTAssertEqual(Autocorrect.suggestions(for: "nao", checker: checker).autocorrection, "não")
    }

    func testCandidatesDropTheTypedWordAndDuplicates() {
        let checker = FakeChecker(guesses: ["tudoe": ["tudoe", "tudo", "Tudo", "todos"]])
        XCTAssertEqual(Autocorrect.suggestions(for: "tudoe", checker: checker).candidates, ["tudo", "todos"])
    }

    func testReplaceActions() {
        XCTAssertEqual(Autocorrect.replaceActions(word: "tudoe", with: "tudo"), [.deleteBackward(5), .insert("tudo")])
    }

    func testTriggersOnSpaceAndPunctuation() {
        XCTAssertTrue(Autocorrect.triggers(on: " "))
        XCTAssertTrue(Autocorrect.triggers(on: ","))
        XCTAssertTrue(Autocorrect.triggers(on: "?"))
        XCTAssertFalse(Autocorrect.triggers(on: "a"))
        XCTAssertFalse(Autocorrect.triggers(on: "-"))
    }
}
