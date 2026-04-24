import XCTest
@testable import MacBookOptimizationApp

final class MemoryMonitoringServiceTests: XCTestCase {
    func testSnapshotCommandCollectsRamSwapAndVmStat() {
        let command = MemorySnapshotCommand.combinedCommand

        XCTAssertTrue(command.contains("Total RAM Bytes"))
        XCTAssertTrue(command.contains("sysctl vm.swapusage"))
        XCTAssertTrue(command.contains("vm_stat"))
    }
}
