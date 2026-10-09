import XCTest
@testable import KeyboardCore

final class TextReplacerTests: XCTestCase {
    func testSelectionTakesPriority() {
        let r = TextReplacer.target(selectedText: "olá mundo", contextBefore: "antes olá mundo")
        XCTAssertEqual(r, .success(ImproveTarget(text: "olá mundo", mode: .selection)))
    }

    func testFallsBackToTextBeforeCursor() {
        XCTAssertEqual(TextReplacer.target(selectedText: nil, contextBefore: "boas tudo bem"),
                       .success(ImproveTarget(text: "boas tudo bem", mode: .beforeCursor)))
        XCTAssertEqual(TextReplacer.target(selectedText: "", contextBefore: "boas"),
                       .success(ImproveTarget(text: "boas", mode: .beforeCursor)))
    }

    func testEmptyAndTooLong() {
        XCTAssertEqual(TextReplacer.target(selectedText: nil, contextBefore: nil), .failure(.empty))
        XCTAssertEqual(TextReplacer.target(selectedText: "  ", contextBefore: " \n "), .failure(.empty))
        let max = String(repeating: "a", count: TextReplacer.maxLength)
        XCTAssertEqual(TextReplacer.target(selectedText: nil, contextBefore: max),
                       .success(ImproveTarget(text: max, mode: .beforeCursor)))
        XCTAssertEqual(TextReplacer.target(selectedText: nil, contextBefore: max + "a"), .failure(.tooLong))
    }

    func testReplacementPreservesSurroundingWhitespace() {
        XCTAssertEqual(TextReplacer.preservingWhitespace(of: "olá tudo bem ", in: "Olá, tudo bem?"),
                       "Olá, tudo bem? ")
        XCTAssertEqual(TextReplacer.preservingWhitespace(of: "\n  oi\n", in: "  Oi!  "), "\n  Oi!\n")
        XCTAssertEqual(TextReplacer.preservingWhitespace(of: "oi", in: "Oi!"), "Oi!")
    }

    func testReplaceActions() {
        let before = ImproveTarget(text: "boas tudo bem", mode: .beforeCursor)
        XCTAssertEqual(TextReplacer.replaceActions(for: before, with: "Boas, tudo bem?"),
                       [.deleteBackward(13), .insert("Boas, tudo bem?")])
        let selection = ImproveTarget(text: "boas", mode: .selection)
        XCTAssertEqual(TextReplacer.replaceActions(for: selection, with: "Boas!"), [.insert("Boas!")])
    }

    func testDeleteCountUsesCharacters() {
        let target = ImproveTarget(text: "olá 👋🏽 e\u{301}", mode: .beforeCursor)
        XCTAssertEqual(TextReplacer.replaceActions(for: target, with: "x"), [.deleteBackward(7), .insert("x")])
        let context = "Disse: " + target.text
        let after = TextAction.apply(TextReplacer.replaceActions(for: target, with: "Olá 👋🏽 é"), to: context)
        XCTAssertEqual(after, "Disse: Olá 👋🏽 é")
    }

    func testUndoRestoresOriginal() {
        for mode in [TargetMode.beforeCursor, .selection] {
            let target = ImproveTarget(text: "boas 👋🏽", mode: mode)
            let replacement = "Boas! 👋🏽"
            let undo = TextReplacer.undoActions(for: target, replacement: replacement)
            XCTAssertEqual(undo, [.deleteBackward(7), .insert("boas 👋🏽")])
            XCTAssertEqual(TextAction.apply(undo, to: "x " + replacement), "x boas 👋🏽")
        }
    }

    func testContextStillMatches() {
        let before = ImproveTarget(text: "boas", mode: .beforeCursor)
        XCTAssertTrue(TextReplacer.contextStillMatches(before, selectedText: nil, contextBefore: "olá boas"))
        XCTAssertFalse(TextReplacer.contextStillMatches(before, selectedText: nil, contextBefore: "boas!"))
        XCTAssertFalse(TextReplacer.contextStillMatches(before, selectedText: nil, contextBefore: nil))
        let selection = ImproveTarget(text: "boas", mode: .selection)
        XCTAssertTrue(TextReplacer.contextStillMatches(selection, selectedText: "boas", contextBefore: ""))
        XCTAssertFalse(TextReplacer.contextStillMatches(selection, selectedText: nil, contextBefore: "boas"))
    }
}
