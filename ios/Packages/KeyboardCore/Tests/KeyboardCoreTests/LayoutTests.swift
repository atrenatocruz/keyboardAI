import XCTest
@testable import KeyboardCore

final class LayoutTests: XCTestCase {
    private func chars(_ row: [Key]) -> [String] {
        row.compactMap { if case .character(let c) = $0 { return c } else { return nil } }
    }

    func testLettersPageHasPortugueseQwertyWithCedilla() {
        let rows = KeyboardLayout.rows(for: .letters, includeNextKeyboard: true)
        XCTAssertEqual(rows.count, 4)
        XCTAssertEqual(chars(rows[0]), ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"])
        XCTAssertEqual(chars(rows[1]), ["a", "s", "d", "f", "g", "h", "j", "k", "l", "ç"])
        XCTAssertEqual(rows[2].first, .shift)
        XCTAssertEqual(rows[2].last, .delete)
        XCTAssertEqual(chars(rows[2]), ["z", "x", "c", "v", "b", "n", "m"])
        XCTAssertEqual(rows[3], [.page(.numbers), .nextKeyboard, .space, .returnKey])
    }

    func testNextKeyboardKeyIsOptional() {
        let rows = KeyboardLayout.rows(for: .letters, includeNextKeyboard: false)
        XCTAssertEqual(rows[3], [.page(.numbers), .space, .returnKey])
    }

    func testNumbersAndSymbolsPages() {
        let numbers = KeyboardLayout.rows(for: .numbers, includeNextKeyboard: false)
        XCTAssertEqual(chars(numbers[0]), ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"])
        XCTAssertTrue(chars(numbers[1]).contains("€"))
        XCTAssertEqual(numbers[2].first, .page(.symbols))
        XCTAssertEqual(numbers[3].first, .page(.letters))

        let symbols = KeyboardLayout.rows(for: .symbols, includeNextKeyboard: false)
        XCTAssertTrue(chars(symbols[1]).contains("«"))
        XCTAssertTrue(chars(symbols[1]).contains("»"))
        XCTAssertEqual(symbols[2].first, .page(.numbers))
        XCTAssertEqual(symbols[3].first, .page(.letters))
    }

    func testAccentVariants() {
        XCTAssertEqual(Accents.variants(for: "a", uppercase: false), ["á", "à", "â", "ã", "ª"])
        XCTAssertEqual(Accents.variants(for: "a", uppercase: true), ["Á", "À", "Â", "Ã", "ª"])
        XCTAssertEqual(Accents.variants(for: "e", uppercase: false), ["é", "ê", "è"])
        XCTAssertEqual(Accents.variants(for: "o", uppercase: true), ["Ó", "Ô", "Õ", "º"])
        XCTAssertEqual(Accents.variants(for: "u", uppercase: false), ["ú", "ü"])
        XCTAssertEqual(Accents.variants(for: "i", uppercase: false), ["í"])
        XCTAssertEqual(Accents.variants(for: "c", uppercase: false), ["ç"])
        XCTAssertEqual(Accents.variants(for: "n", uppercase: false), ["ñ"])
        XCTAssertEqual(Accents.variants(for: "A", uppercase: false), ["á", "à", "â", "ã", "ª"])
        XCTAssertEqual(Accents.variants(for: "z", uppercase: false), [])
    }
}
