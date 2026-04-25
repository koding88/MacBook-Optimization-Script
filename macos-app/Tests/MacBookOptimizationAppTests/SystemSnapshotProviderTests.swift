import XCTest
@testable import MacBookOptimizationApp

final class SystemSnapshotProviderTests: XCTestCase {
    func testStorageUsedIsDerivedFromTotalAndAvailable() async {
        let provider = SystemSnapshotProvider()

        let snapshot = await provider.storageSnapshot(
            totalBytesOverride: 494_000_000_000,
            availableBytesOverride: 167_000_000_000
        )

        XCTAssertEqual(snapshot.usedBytes, 327_000_000_000)
    }

    func testStorageSnapshotPrefersAvailableCapacityForImportantUsage() async {
        let provider = SystemSnapshotProvider(
            resourceValuesProvider: {
                SystemSnapshotProvider.StorageResourceValues(
                    totalCapacity: 512_000_000_000,
                    availableCapacity: 150_000_000_000,
                    availableCapacityForImportantUsage: 167_000_000_000
                )
            }
        )

        let snapshot = await provider.storageSnapshot()

        XCTAssertEqual(snapshot.totalBytes, 512_000_000_000)
        XCTAssertEqual(snapshot.availableBytes, 167_000_000_000)
        XCTAssertEqual(snapshot.usedBytes, 345_000_000_000)
    }
}
