import XCTest
@testable import KeyboardCore

final class MoodTests: XCTestCase {
    func testRawValuesMatchApiContract() {
        XCTAssertEqual(Mood.allCases.map(\.rawValue),
                       ["natural", "simpatico", "profissional", "direto", "descontraido"])
    }

    func testDisplayNamesAndExamples() {
        XCTAssertEqual(Mood.allCases.map(\.displayName),
                       ["Natural", "Simpático", "Profissional", "Direto", "Descontraído"])
        XCTAssertEqual(Mood.exampleInput, "boas, consegues me mandar isso quando tiveres tempo?")
        XCTAssertEqual(Mood.natural.exampleOutput,
                       "Boas! Consegues mandar-me isso quando tiveres um bocadinho de tempo?")
        for mood in Mood.allCases {
            XCTAssertFalse(mood.summary.isEmpty)
            XCTAssertFalse(mood.exampleOutput.isEmpty)
        }
    }

    func testApplyTextActions() {
        let result = TextAction.apply([.insert("olá"), .deleteBackward(1), .insert("a 👋🏽"), .deleteBackward(1)],
                                      to: "Diz ")
        XCTAssertEqual(result, "Diz ola ")
        XCTAssertEqual(TextAction.apply([.deleteBackward(10)], to: "ab"), "")
    }

    func testStatusMessagesArePortuguese() {
        XCTAssertEqual(AIStatusMessage.noFullAccess.text, "Ativa o Acesso total para usar a IA")
        XCTAssertEqual(AIStatusMessage.offline.text, "Sem ligação. Tenta outra vez.")
        XCTAssertEqual(AIStatusMessage.timeout.text, "Sem ligação. Tenta outra vez.")
        XCTAssertEqual(AIStatusMessage.dailyLimit.text, "Atingiste o limite de hoje")
        XCTAssertEqual(AIStatusMessage.tooLong.text, "Texto demasiado longo")
        XCTAssertEqual(AIStatusMessage.server.text, "Algo correu mal. Tenta outra vez.")
        XCTAssertEqual(AIStatusMessage.unchanged.text, "✓ Já está ótimo")
        XCTAssertEqual(AIStatusMessage.contextChanged.text, "O texto mudou")
    }
}
