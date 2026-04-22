import XCTest
@testable import MacBookOptimizationApp

final class StateStoreTests: XCTestCase {
    func testUpdateStatePersistsFeatureState() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent(".macbook_optimizer_state.conf")
        let store = StateStore(configURL: fileURL)

        try store.updateState(
            featureID: "dns_flush",
            status: .enabled,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let states = try store.loadStates()
        XCTAssertEqual(states["dns_flush"]?.status, "enabled")
        XCTAssertNotNil(states["dns_flush"]?.timestamp)
        XCTAssertEqual(states["dns_flush"]?.timestamp.count, 19)
        XCTAssertTrue(states["dns_flush"]?.timestamp.contains(":") == true)
    }

    func testLoadStatesIgnoresMalformedLines() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent(".macbook_optimizer_state.conf")
        try """
        malformed
        firewall=enabled|2026-03-28 12:00:00
        invalid=line=thing
        """.write(to: fileURL, atomically: true, encoding: .utf8)

        let store = StateStore(configURL: fileURL)
        let states = try store.loadStates()

        XCTAssertEqual(states.count, 1)
        XCTAssertEqual(states["firewall"]?.status, "enabled")
    }

    func testResetStatesClearsExistingEntries() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent(".macbook_optimizer_state.conf")
        let store = StateStore(configURL: fileURL)

        try store.updateState(
            featureID: "dns_flush",
            status: .enabled,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        )

        try store.resetStates()

        let states = try store.loadStates()
        XCTAssertTrue(states.isEmpty)
    }
}
