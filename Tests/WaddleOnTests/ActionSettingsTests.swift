import XCTest
@testable import WaddleOn

final class ActionSettingsTests: XCTestCase {
    func testDefaultsPersistenceAndIntervalBounds() throws {
        let name = "WaddleOnTests.Actions.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = SettingsStore(defaults: defaults)
        XCTAssertTrue(store.snowballsEnabled)
        XCTAssertEqual(store.snowballInterval, 20)
        store.snowballsEnabled = false
        store.snowballInterval = 45
        let reopened = SettingsStore(defaults: defaults)
        XCTAssertFalse(reopened.snowballsEnabled)
        XCTAssertEqual(reopened.snowballInterval, 45)
        store.snowballInterval = -1
        XCTAssertEqual(store.snowballInterval, 5)
        store.snowballInterval = 999
        XCTAssertEqual(store.snowballInterval, 300)
        store.snowballInterval = .nan
        XCTAssertEqual(store.snowballInterval, 20)
    }
}
