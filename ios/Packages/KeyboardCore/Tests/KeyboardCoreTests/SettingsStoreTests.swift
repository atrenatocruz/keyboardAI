import XCTest
@testable import KeyboardCore

final class SettingsStoreTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        defaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
    }

    func testInstallIDIsStableLowercaseUUID() {
        let store = SettingsStore(defaults: defaults)
        let id = store.installID
        XCTAssertNotNil(UUID(uuidString: id))
        XCTAssertEqual(id, id.lowercased())
        XCTAssertEqual(SettingsStore(defaults: defaults).installID, id)
    }

    func testMoodDefaultsToNaturalAndPersists() {
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.mood, .natural)
        store.mood = .direto
        XCTAssertEqual(SettingsStore(defaults: defaults).mood, .direto)
    }

    func testHapticsDefaultOnAndPersists() {
        let store = SettingsStore(defaults: defaults)
        XCTAssertTrue(store.hapticsEnabled)
        store.hapticsEnabled = false
        XCTAssertFalse(SettingsStore(defaults: defaults).hapticsEnabled)
    }
}
