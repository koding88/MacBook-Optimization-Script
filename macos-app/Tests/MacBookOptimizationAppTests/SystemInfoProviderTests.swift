import XCTest
@testable import MacBookOptimizationApp

final class SystemInfoProviderTests: XCTestCase {
    func testHardwareSnapshotUsesMarketingNameAndModelIdentifier() {
        let snapshot = SystemInfoProvider.hardwareSnapshot(
            from: [
                "machine_name": "MacBook Pro",
                "machine_model": "Mac14,10",
                "chip_type": "Apple M2 Pro",
                "serial_number": "ABC123"
            ]
        )

        XCTAssertEqual(
            snapshot,
            SystemInfoProvider.HardwareSnapshot(
                marketingModel: "MacBook Pro",
                modelIdentifier: "Mac14,10",
                chipName: "Apple M2 Pro",
                serialNumber: "ABC123"
            )
        )
    }

    func testHardwareSnapshotReturnsNilWhenRequiredFieldsAreMissing() {
        XCTAssertNil(SystemInfoProvider.hardwareSnapshot(from: ["machine_model": "Mac14,10"]))
        XCTAssertNil(SystemInfoProvider.hardwareSnapshot(from: ["machine_name": "MacBook Pro"]))
    }
}
