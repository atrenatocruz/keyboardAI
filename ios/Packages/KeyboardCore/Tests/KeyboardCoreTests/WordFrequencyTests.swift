import XCTest
@testable import KeyboardCore

private struct Checker: SpellChecking {
    var known: Set<String>
    var guesses: [String: [String]] = [:]
    func isKnown(_ word: String) -> Bool { known.contains(word.lowercased()) }
    func guesses(for word: String) -> [String] { guesses[word.lowercased()] ?? [] }
    func completions(for partial: String) -> [String] { [] }
}

final class WordFrequencyTests: XCTestCase {
    private let words = WordFrequency(text: """
    que 7796660
    o 7310536
    não 6184188
    de 5386265
    e 3648721
    está 1730804
    tudo 568890
    você 495201
    obrigado 247510
    obrigada 120000
    esta 300000
    todos 200000
    tido 3000
    nao 20855
    bro 2500
    boro 40
    casa 150000
    caso 90000
    """)

    private let checker = Checker(known: ["que", "o", "não", "de", "e", "está", "tudo", "você", "obrigado", "obrigada",
                                          "esta", "todos", "tido", "boro", "casa", "caso", "obri"])

    func testParsesCountsAndLookups() {
        XCTAssertEqual(words.count(of: "tudo"), 568890)
        XCTAssertEqual(words.count(of: "Tudo"), 568890)
        XCTAssertEqual(words.count(of: "xyz"), 0)
    }

    func testCompletionsAreOrderedByFrequency() {
        XCTAssertEqual(words.completions(prefix: "obri", limit: 5), ["obrigado", "obrigada"])
        XCTAssertEqual(words.completions(prefix: "t", limit: 2), ["tudo", "todos"])
    }

    func testAccentVariantsShareTheFoldedForm() {
        XCTAssertEqual(Set(words.accentVariants(of: "nao")), ["não", "nao"])
        XCTAssertEqual(Set(words.accentVariants(of: "esta")), ["está", "esta"])
    }

    func testMissingAccentIsCorrected() {
        let s = Autocorrect.suggestions(for: "nao", checker: checker, frequency: words)
        XCTAssertEqual(s.autocorrection, "não")
        XCTAssertEqual(Autocorrect.suggestions(for: "voce", checker: checker, frequency: words).autocorrection, "você")
    }

    func testExtraLetterIsCorrectedToTheMostCommonWord() {
        let s = Autocorrect.suggestions(for: "tudoe", checker: checker, frequency: words)
        XCTAssertEqual(s.autocorrection, "tudo")
        XCTAssertEqual(s.typed, "tudoe")
    }

    func testAdjacentKeyTypoBeatsRandomSubstitution() {
        // "casp": o sits next to p, a doesn't — so "caso" beats the more frequent "casa".
        let s = Autocorrect.suggestions(for: "casp", checker: checker, frequency: words)
        XCTAssertEqual(s.autocorrection, "caso")
    }

    func testDoubledLetterPrefersDroppingTheRepeat() {
        let list = WordFrequency(text: "coisa 300000\ncoisas 150000")
        let known = Checker(known: ["coisa", "coisas"])
        XCTAssertEqual(Autocorrect.suggestions(for: "coisaa", checker: known, frequency: list).autocorrection, "coisa")
    }

    func testChatAbbreviationsAreNeverCorrected() {
        let list = WordFrequency(text: "tem 900000\nong 5000")
        let known = Checker(known: ["tem", "ong"])
        XCTAssertNil(Autocorrect.suggestions(for: "tbm", checker: known, frequency: list).autocorrection)
        XCTAssertNil(Autocorrect.suggestions(for: "obg", checker: known, frequency: list).autocorrection)
    }

    func testCommonSlangIsLeftAlone() {
        let s = Autocorrect.suggestions(for: "bro", checker: checker, frequency: words)
        XCTAssertNil(s.autocorrection)
    }

    func testKnownWordOffersAccentedAlternativeWithoutCorrecting() {
        let s = Autocorrect.suggestions(for: "esta", checker: checker, frequency: words)
        XCTAssertNil(s.autocorrection)
        XCTAssertEqual(s.candidates.first, "está")
    }

    func testKnownPrefixOffersCompletionsSkippingMisspellings() {
        let s = Autocorrect.suggestions(for: "obri", checker: checker, frequency: words)
        XCTAssertNil(s.autocorrection)
        XCTAssertEqual(s.candidates, ["obrigado", "obrigada"])
    }

    func testPredictionsWhenNoWordIsBeingTyped() {
        let start = Autocorrect.predictions(after: "", checker: checker, frequency: words)
        XCTAssertNil(start.typed)
        XCTAssertEqual(start.candidates.count, 3)
        XCTAssertTrue(start.candidates.allSatisfy { $0.first?.isUppercase == true })

        let middle = Autocorrect.predictions(after: "Olá tudo ", checker: checker, frequency: words)
        XCTAssertEqual(middle.candidates.count, 3)
        XCTAssertFalse(middle.candidates.contains("tudo"))
        XCTAssertTrue(middle.candidates.allSatisfy { $0.first?.isLowercase == true })
    }
}
