import XCTest
@testable import KeyboardCore

final class EngineTests: XCTestCase {
    func testStartsCapitalizedAndTurnsOffAfterFirstLetter() {
        var e = KeyboardEngine()
        XCTAssertEqual(e.state.shift, .on)
        XCTAssertEqual(e.handle(.character("b"), contextBefore: ""), [.insert("B")])
        XCTAssertEqual(e.state.shift, .off)
        XCTAssertEqual(e.handle(.character("o"), contextBefore: "B"), [.insert("o")])
    }

    func testShiftTapAndCapsLock() {
        var e = KeyboardEngine()
        e.updateAutoCapitalization(contextBefore: "olá")
        XCTAssertEqual(e.state.shift, .off)
        XCTAssertEqual(e.handle(.shift(doubleTap: false), contextBefore: "olá"), [])
        XCTAssertEqual(e.state.shift, .on)
        _ = e.handle(.shift(doubleTap: true), contextBefore: "olá")
        XCTAssertEqual(e.state.shift, .capsLock)
        XCTAssertEqual(e.handle(.character("a"), contextBefore: "olá"), [.insert("A")])
        XCTAssertEqual(e.handle(.character("b"), contextBefore: "oláA"), [.insert("B")])
        XCTAssertEqual(e.state.shift, .capsLock)
        _ = e.handle(.space, contextBefore: "oláAB")
        XCTAssertEqual(e.state.shift, .capsLock)
        _ = e.handle(.shift(doubleTap: false), contextBefore: "oláAB ")
        XCTAssertEqual(e.state.shift, .off)
    }

    func testAutoCapitalizationAfterSentenceEndAndNewline() {
        XCTAssertTrue(KeyboardEngine.shouldCapitalize(""))
        XCTAssertTrue(KeyboardEngine.shouldCapitalize("Olá. "))
        XCTAssertTrue(KeyboardEngine.shouldCapitalize("Sim? "))
        XCTAssertTrue(KeyboardEngine.shouldCapitalize("Boa!  "))
        XCTAssertTrue(KeyboardEngine.shouldCapitalize("linha\n"))
        XCTAssertTrue(KeyboardEngine.shouldCapitalize("   "))
        XCTAssertFalse(KeyboardEngine.shouldCapitalize("Olá."))
        XCTAssertFalse(KeyboardEngine.shouldCapitalize("olá "))
        XCTAssertFalse(KeyboardEngine.shouldCapitalize("olá, "))

        var e = KeyboardEngine()
        _ = e.handle(.character("a"), contextBefore: "Olá")
        XCTAssertEqual(e.state.shift, .off)
        _ = e.handle(.space, contextBefore: "Olá.")
        XCTAssertEqual(e.state.shift, .on)
    }

    func testAutoCapitalizationDisabled() {
        var e = KeyboardEngine(autoCapitalizationEnabled: false)
        XCTAssertEqual(e.state.shift, .off)
        XCTAssertEqual(e.handle(.character("r"), contextBefore: ""), [.insert("r")])
        _ = e.handle(.space, contextBefore: "ok.")
        XCTAssertEqual(e.state.shift, .off)
    }

    func testDoubleSpaceInsertsPeriod() {
        var e = KeyboardEngine()
        XCTAssertEqual(e.handle(.space, contextBefore: "olá "), [.deleteBackward(1), .insert(". ")])
        XCTAssertEqual(e.state.shift, .on)
        XCTAssertEqual(e.handle(.space, contextBefore: "tenho 3 "), [.deleteBackward(1), .insert(". ")])
    }

    func testDoubleSpaceAfterPunctuationDoesNothing() {
        var e = KeyboardEngine()
        XCTAssertEqual(e.handle(.space, contextBefore: "ok. "), [.insert(" ")])
        XCTAssertEqual(e.handle(.space, contextBefore: " "), [.insert(" ")])
        XCTAssertEqual(e.handle(.space, contextBefore: ""), [.insert(" ")])
        XCTAssertEqual(e.handle(.space, contextBefore: "olá  "), [.insert(" ")])
        XCTAssertEqual(e.handle(.space, contextBefore: "😀 "), [.insert(" ")])
    }

    func testDeleteAndReturn() {
        var e = KeyboardEngine()
        XCTAssertEqual(e.handle(.delete, contextBefore: "Olá. a"), [.deleteBackward(1)])
        XCTAssertEqual(e.state.shift, .on)
        XCTAssertEqual(e.handle(.delete, contextBefore: ""), [.deleteBackward(1)])
        XCTAssertEqual(e.handle(.returnKey, contextBefore: "olá"), [.insert("\n")])
        XCTAssertEqual(e.state.shift, .on)
    }

    func testPagesAndReturnToLettersAfterSpace() {
        var e = KeyboardEngine()
        XCTAssertEqual(e.handle(.switchPage(.numbers), contextBefore: "a"), [])
        XCTAssertEqual(e.state.page, .numbers)
        XCTAssertEqual(e.handle(.character("3"), contextBefore: "a"), [.insert("3")])
        XCTAssertEqual(e.state.page, .numbers)
        _ = e.handle(.space, contextBefore: "a3")
        XCTAssertEqual(e.state.page, .letters)
    }

    func testDisplayText() {
        var e = KeyboardEngine()
        XCTAssertEqual(e.displayText(for: "ç"), "Ç")
        e.updateAutoCapitalization(contextBefore: "a")
        XCTAssertEqual(e.displayText(for: "ç"), "ç")
    }
}
