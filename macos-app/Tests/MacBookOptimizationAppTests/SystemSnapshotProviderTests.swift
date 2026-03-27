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
}
